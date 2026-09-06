// 数据云 OpenApi 爬取脚本（根据《数据云OpenApi接口规范》及 listByPageAll 接口）
// 认证：AccessKey(Id) + TimeStamp + Sign(MD5(AccessKeyId+AccessKeySecret+TimeStamp) 十六进制)
// 接口：findSku 查单个物料、materialCodeList 物料编码更改记录、listByPageAll 批量查物料详情
package main

import (
	"bytes"
	"crypto/md5"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

const (
	prodBase             = "https://ecloud.jiepei.com/api/search/OpenApi"
	starrocksHost        = "192.168.19.21"
	starrocksPort        = "9030"
	starrocksUser        = "root"
	streamLoadBaseURL    = "http://192.168.19.21:8040" // Stream Load 写死地址
	detailTableColumns   = "id,keyword,brand_name,package,material_code,data_sheet,extended_attributes,kicad_doc_url"
	streamLoadBatchSize       = 200  // 单次 Stream Load 行数，避免 primary key size exceed the limit
	listByPageAllRetryDelay   = 15   // 批次失败后重试等待秒数（服务器波动时延长等待）
)

// ComponentQuery listByPageAll 单条查询条件
type ComponentQuery struct {
	Model         string `json:"model"`
	Brand         string `json:"brand,omitempty"`
	Encapsulation string `json:"encapsulation,omitempty"`
}

// detailRow 写入 ods_jp_component_sku_detail 的一行
type detailRow struct {
	id, keyword, brandName, pkg, materialCode, dataSheet, extendedAttr, kicadDocURL string
}

// listByPageAllItem listByPageAll 单条返回
type listByPageAllItem struct {
	ID                 *string          `json:"id"`
	MaterialCode       *string          `json:"materialCode"`
	Model              string           `json:"model"`
	DataSheet          *string          `json:"dataSheet"`
	ExtendedAttributes *json.RawMessage `json:"extendedAttributes"`
	KicadDocURL        *string          `json:"kicadDocUrl"`
}

func main() {
	baseURL := flag.String("base", prodBase, "API base URL")
	cmd := flag.String("cmd", "", "findSku | materialCodeList | listByPageAll | listByPageAllFromTable")
	model := flag.String("model", "", "findSku: 型号")
	brand := flag.String("brand", "", "findSku: 品牌")
	encapsulation := flag.String("encapsulation", "", "findSku: 封装")
	startTime := flag.String("startTime", "", "materialCodeList: 开始日期")
	endTime := flag.String("endTime", "", "materialCodeList: 结束日期")
	inputFile := flag.String("input", "", "listByPageAll: JSON 文件或 -")
	dsn := flag.String("dsn", "", "listByPageAllFromTable: StarRocks DSN")
	dbName := flag.String("db", "ods", "listByPageAllFromTable: 数据库名")
	tableName := flag.String("table", "ods_jp_component_sku", "listByPageAllFromTable: 表名")
	limit := flag.Int("limit", 0, "listByPageAllFromTable: 最多读取行数，0 表示全表分页")
	offset := flag.Int("offset", 0, "listByPageAllFromTable: 从第几条开始（0 表示从头）")
	pageSize := flag.Int("page-size", 5000, "listByPageAllFromTable: 每页行数")
	workers := flag.Int("workers", 10, "listByPageAllFromTable: 并发请求数")
	detailTable := flag.String("detail-table", "", "listByPageAllFromTable: 写入该表（如 ods_jp_component_sku_detail）")
	flag.Parse()

	akID := os.Getenv("OPENAPI_ACCESS_KEY_ID")
	akSecret := os.Getenv("OPENAPI_ACCESS_KEY_SECRET")
	if akID == "" || akSecret == "" {
		log.Fatal("need env OPENAPI_ACCESS_KEY_ID and OPENAPI_ACCESS_KEY_SECRET")
	}

	client := &OpenApiClient{BaseURL: *baseURL, AkID: akID, AkSecret: akSecret}

	switch *cmd {
	case "findSku":
		if *model == "" || *brand == "" || *encapsulation == "" {
			log.Fatal("findSku needs -model, -brand, -encapsulation")
		}
		out, err := client.FindSku(*model, *brand, *encapsulation)
		if err != nil {
			log.Fatalf("findSku: %v", err)
		}
		fmt.Println(string(out))
	case "materialCodeList":
		if *startTime == "" || *endTime == "" {
			log.Fatal("materialCodeList needs -startTime, -endTime")
		}
		out, err := client.MaterialCodeList(*startTime, *endTime)
		if err != nil {
			log.Fatalf("materialCodeList: %v", err)
		}
		fmt.Println(string(out))
	case "listByPageAll":
		if *inputFile == "" {
			if *model != "" {
				list := []ComponentQuery{{Model: *model, Brand: *brand, Encapsulation: *encapsulation}}
				out, err := client.ListByPageAll(list)
				if err != nil {
					log.Fatalf("listByPageAll: %v", err)
				}
				fmt.Println(string(out))
				return
			}
			log.Fatal("listByPageAll needs -input <file|-> or -model")
		}
		var raw []byte
		var err error
		if *inputFile == "-" {
			raw, err = io.ReadAll(os.Stdin)
		} else {
			raw, err = os.ReadFile(*inputFile)
		}
		if err != nil {
			log.Fatalf("read input: %v", err)
		}
		var list []ComponentQuery
		if err := json.Unmarshal(raw, &list); err != nil {
			log.Fatalf("parse JSON: %v", err)
		}
		if len(list) > 100 {
			log.Fatalf("listByPageAll at most 100 items, got %d", len(list))
		}
		out, err := client.ListByPageAll(list)
		if err != nil {
			log.Fatalf("listByPageAll: %v", err)
		}
		fmt.Println(string(out))
	case "listByPageAllFromTable":
		runListByPageAllFromTable(client, *dsn, *dbName, *tableName, *limit, *offset, *detailTable, *pageSize, *workers)
	default:
		log.Fatal("use -cmd findSku | materialCodeList | listByPageAll | listByPageAllFromTable")
	}
}

func runListByPageAllFromTable(client *OpenApiClient, dsn, dbName, tableName string, limit, startOffset int, detailTable string, pageSize, workers int) {
	if dsn == "" {
		dsn = os.Getenv("STARROCKS_DSN")
	}
	pass := os.Getenv("STARROCKS_PASSWORD")
	user := os.Getenv("STARROCKS_USER")
	if user == "" {
		user = starrocksUser
	}
	if dsn == "" {
		dsn = fmt.Sprintf("%s:%s@tcp(%s:%s)/", user, pass, starrocksHost, starrocksPort)
	}
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		log.Fatalf("ping db: %v", err)
	}

	if limit == 0 {
		if detailTable == "" {
			log.Fatal("listByPageAllFromTable 全表跑（limit=0）时必须指定 -detail-table")
		}
		if pageSize <= 0 {
			pageSize = 5000
		}
		if workers <= 0 {
			workers = 10
		}
		runFullSync(client, db, dbName, tableName, detailTable, startOffset, pageSize, workers, user, pass)
		return
	}

	list := queryComponentList(db, dbName, tableName, fmt.Sprintf("SELECT keyword, brand_name, package FROM %s.%s LIMIT %d", dbName, tableName, limit))
	if len(list) == 0 {
		log.Printf("no rows from %s.%s", dbName, tableName)
		return
	}
	log.Printf("read %d rows from %s.%s, calling listByPageAll in batches of 100", len(list), dbName, tableName)
	allData := fetchBatchesSequential(client, list)
	if detailTable != "" && len(allData) > 0 {
		n := writeDetailTable(db, streamLoadBaseURL, user, pass, dbName, detailTable, list, allData)
		log.Printf("写入成功，从第 1 条到第 %d 条（本页写入 %d 条）", len(list), n)
	}
}

func queryComponentList(db *sql.DB, dbName, tableName, query string) []ComponentQuery {
	log.Printf("query: %s", query)
	rows, err := db.Query(query)
	if err != nil {
		log.Fatalf("query: %v", err)
	}
	defer rows.Close()
	var list []ComponentQuery
	for rows.Next() {
		var keyword, brandName, pkg sql.NullString
		if err := rows.Scan(&keyword, &brandName, &pkg); err != nil {
			log.Fatalf("scan row: %v", err)
		}
		model, brand, encap := "", "", ""
		if keyword.Valid {
			model = keyword.String
		}
		if brandName.Valid {
			brand = brandName.String
		}
		if pkg.Valid {
			encap = pkg.String
		}
		list = append(list, ComponentQuery{Model: model, Brand: brand, Encapsulation: encap})
	}
	if err := rows.Err(); err != nil {
		log.Fatalf("rows: %v", err)
	}
	return list
}

func fetchBatchesSequential(client *OpenApiClient, list []ComponentQuery) []json.RawMessage {
	var allData []json.RawMessage
	for i := 0; i < len(list); i += 100 {
		end := i + 100
		if end > len(list) {
			end = len(list)
		}
		batch := list[i:end]
		out, err := client.ListByPageAll(batch)
		if err != nil {
			log.Printf("listByPageAll batch %d-%d failed: %v", i, end, err)
			continue
		}
		var resp struct {
			Data []json.RawMessage `json:"data"`
		}
		if err := json.Unmarshal(out, &resp); err != nil {
			log.Printf("parse response: %v", err)
			continue
		}
		allData = append(allData, resp.Data...)
	}
	return allData
}

func runFullSync(client *OpenApiClient, db *sql.DB, dbName, tableName, detailTable string, startOffset, pageSize, workers int, user, pass string) {
	baseQuery := fmt.Sprintf("SELECT keyword, brand_name, package FROM %s.%s ORDER BY keyword, brand_name, package", dbName, tableName)
	offset := startOffset
	if offset > 0 {
		log.Printf("从第 %d 条开始同步", offset+1)
	}
	totalFetched := 0
	totalWritten := 0
	for {
		query := baseQuery + fmt.Sprintf(" LIMIT %d OFFSET %d", pageSize, offset)
		list := queryComponentList(db, dbName, tableName, query)
		if len(list) == 0 {
			break
		}
		log.Printf("page offset %d: read %d rows, fetching with %d workers (%d batches)", offset, len(list), workers, (len(list)+99)/100)
		results, failed := fetchBatchesConcurrent(client, list, workers)
		for len(failed) > 0 {
			log.Printf("page offset %d: %d batches failed, retrying in %ds...", offset, len(failed), listByPageAllRetryDelay)
			time.Sleep(time.Duration(listByPageAllRetryDelay) * time.Second)
			retryResults, retryFailed := fetchBatchIndices(client, list, failed, workers)
			for j, idx := range failed {
				results[idx] = retryResults[j]
			}
			failed = retryFailed
		}
		allData := flattenBatchResults(results)
		totalFetched += len(list)
		if detailTable != "" && len(allData) > 0 {
			n := writeDetailTable(db, streamLoadBaseURL, user, pass, dbName, detailTable, list, allData)
			totalWritten += n
			log.Printf("写入成功，从第 %d 条到第 %d 条（本页写入 %d 条）", offset+1, offset+len(list), n)
		}
		if len(list) < pageSize {
			break
		}
		offset += pageSize
	}
	log.Printf("full sync done: fetched %d rows, wrote %d detail rows", totalFetched, totalWritten)
}

// fetchBatchesConcurrent 并发请求当前页全部批次，返回按批结果与失败批次下标；失败则需重试，不翻页。
func fetchBatchesConcurrent(client *OpenApiClient, list []ComponentQuery, workers int) ([][]json.RawMessage, []int) {
	type result struct {
		index int
		data  []json.RawMessage
		failed bool
	}
	numBatches := (len(list) + 99) / 100
	taskCh := make(chan int, numBatches)
	resultCh := make(chan result, numBatches)
	for i := 0; i < numBatches; i++ {
		taskCh <- i
	}
	close(taskCh)
	for w := 0; w < workers; w++ {
		go func() {
			for i := range taskCh {
				start := i * 100
				end := start + 100
				if end > len(list) {
					end = len(list)
				}
				batch := list[start:end]
				out, err := client.ListByPageAll(batch)
				var data []json.RawMessage
				failed := false
				if err != nil {
					log.Printf("listByPageAll batch %d-%d failed: %v", start, end, err)
					failed = true
				} else {
					var resp struct {
						Data []json.RawMessage `json:"data"`
					}
					if err := json.Unmarshal(out, &resp); err != nil {
						log.Printf("parse response batch %d: %v", i, err)
						failed = true
					} else {
						data = resp.Data
					}
				}
				resultCh <- result{index: i, data: data, failed: failed}
			}
		}()
	}
	results := make([][]json.RawMessage, numBatches)
	var failedIndices []int
	for i := 0; i < numBatches; i++ {
		r := <-resultCh
		results[r.index] = r.data
		if r.failed {
			failedIndices = append(failedIndices, r.index)
		}
	}
	return results, failedIndices
}

// fetchBatchIndices 只请求指定批次下标，用于重试；返回与 batchIndices 同序的 results，以及仍失败的下标。
func fetchBatchIndices(client *OpenApiClient, list []ComponentQuery, batchIndices []int, workers int) ([][]json.RawMessage, []int) {
	type result struct {
		index int
		data  []json.RawMessage
		failed bool
	}
	taskCh := make(chan int, len(batchIndices))
	resultCh := make(chan result, len(batchIndices))
	for _, i := range batchIndices {
		taskCh <- i
	}
	close(taskCh)
	for w := 0; w < workers && w < len(batchIndices); w++ {
		go func() {
			for i := range taskCh {
				start := i * 100
				end := start + 100
				if end > len(list) {
					end = len(list)
				}
				batch := list[start:end]
				out, err := client.ListByPageAll(batch)
				var data []json.RawMessage
				failed := false
				if err != nil {
					log.Printf("listByPageAll batch %d-%d retry failed: %v", start, end, err)
					failed = true
				} else {
					var resp struct {
						Data []json.RawMessage `json:"data"`
					}
					if err := json.Unmarshal(out, &resp); err != nil {
						log.Printf("parse response batch %d retry: %v", i, err)
						failed = true
					} else {
						data = resp.Data
					}
				}
				resultCh <- result{index: i, data: data, failed: failed}
			}
		}()
	}
	results := make([][]json.RawMessage, len(batchIndices))
	var retryFailed []int
	indexInBatch := make(map[int]int)
	for j, idx := range batchIndices {
		indexInBatch[idx] = j
	}
	for range batchIndices {
		r := <-resultCh
		j := indexInBatch[r.index]
		results[j] = r.data
		if r.failed {
			retryFailed = append(retryFailed, r.index)
		}
	}
	return results, retryFailed
}

func flattenBatchResults(results [][]json.RawMessage) []json.RawMessage {
	var all []json.RawMessage
	for _, data := range results {
		all = append(all, data...)
	}
	return all
}

func writeDetailTable(db *sql.DB, feBaseURL, user, pass, dbName, detailTable string, list []ComponentQuery, allData []json.RawMessage) int {
	var rows []detailRow
	for i := 0; i < len(allData) && i < len(list); i++ {
		var item listByPageAllItem
		if err := json.Unmarshal(allData[i], &item); err != nil {
			log.Printf("parse detail item %d: %v", i, err)
			continue
		}
		if item.ID == nil || *item.ID == "" {
			continue
		}
		q := list[i]
		matCode := ""
		if item.MaterialCode != nil {
			matCode = *item.MaterialCode
		}
		ds := ""
		if item.DataSheet != nil {
			ds = *item.DataSheet
		}
		extAttr := ""
		if item.ExtendedAttributes != nil {
			raw := *item.ExtendedAttributes
			var decoded string
			if err := json.Unmarshal(raw, &decoded); err == nil {
				extAttr = decoded
			} else {
				extAttr = string(raw)
			}
		}
		kicad := ""
		if item.KicadDocURL != nil {
			kicad = *item.KicadDocURL
		}
		rows = append(rows, detailRow{
			id: *item.ID, keyword: q.Model, brandName: q.Brand, pkg: q.Encapsulation,
			materialCode: matCode, dataSheet: ds, extendedAttr: extAttr, kicadDocURL: kicad,
		})
	}
	if len(rows) == 0 {
		log.Printf("detail-table: no rows with non-null id, skip write")
		return 0
	}
	streamLoadURL := feBaseURL + "/api/" + dbName + "/" + detailTable + "/_stream_load"
	payload := make([]map[string]interface{}, 0, len(rows))
	for _, r := range rows {
		payload = append(payload, map[string]interface{}{
			"id": r.id, "keyword": r.keyword, "brand_name": r.brandName, "package": r.pkg,
			"material_code": r.materialCode, "data_sheet": r.dataSheet,
			"extended_attributes": r.extendedAttr, "kicad_doc_url": r.kicadDocURL,
		})
	}
	var totalLoaded int
	for start := 0; start < len(payload); start += streamLoadBatchSize {
		end := start + streamLoadBatchSize
		if end > len(payload) {
			end = len(payload)
		}
		chunk := payload[start:end]
		loaded, err := doStreamLoad(streamLoadURL, user, pass, chunk)
		if err != nil {
			if db != nil && strings.Contains(err.Error(), "primary key size exceed the limit") {
				log.Printf("detail-table: stream load failed (primary key size limit), fallback to INSERT")
				return insertDetailTable(db, dbName, detailTable, rows)
			}
			log.Fatalf("detail-table: stream load batch %d-%d: %v", start, end, err)
		}
		totalLoaded += loaded
	}
	return totalLoaded
}

// insertDetailTable 用 INSERT 写入（Stream Load 报 primary key size exceed 时回退），每批 50 条，raw SQL 避免 prepared statement
const insertDetailBatchSize = 50

func insertDetailTable(db *sql.DB, dbName, detailTable string, rows []detailRow) int {
	if len(rows) == 0 {
		return 0
	}
	fullTable := "`" + dbName + "`.`" + detailTable + "`"
	cols := "(id, keyword, brand_name, package, material_code, data_sheet, extended_attributes, kicad_doc_url)"
	var total int
	for start := 0; start < len(rows); start += insertDetailBatchSize {
		end := start + insertDetailBatchSize
		if end > len(rows) {
			end = len(rows)
		}
		batch := rows[start:end]
		var values []string
		for _, r := range batch {
			values = append(values, fmt.Sprintf("(%s,%s,%s,%s,%s,%s,%s,%s)",
				quoteSQL(r.id), quoteSQL(r.keyword), quoteSQL(r.brandName), quoteSQL(r.pkg),
				quoteSQL(r.materialCode), quoteSQL(r.dataSheet), quoteSQLJSON(r.extendedAttr), quoteSQL(r.kicadDocURL)))
		}
		query := fmt.Sprintf("INSERT INTO %s %s VALUES %s", fullTable, cols, strings.Join(values, ","))
		if _, err := db.Exec(query); err != nil {
			if strings.Contains(err.Error(), "primary key size exceed the limit") {
				log.Fatalf("detail-table: INSERT 也报主键长度超限。请修改表结构：主键仅保留 id，或改用 DUPLICATE KEY 表。详见 README。")
			}
			log.Fatalf("detail-table: INSERT batch %d-%d: %v", start, end, err)
		}
		total += len(batch)
	}
	return total
}

func quoteSQL(s string) string {
	s = strings.ReplaceAll(s, "\\", "\\\\")
	s = strings.ReplaceAll(s, "'", "''")
	return "'" + s + "'"
}

func quoteSQLJSON(s string) string {
	s = strings.ReplaceAll(s, "'", "''")
	return "'" + s + "'"
}

// doStreamLoad 与 fetch_data/main.go 的 streamLoad 一致：partial_columns、columns、SetBasicAuth、Expect 100-continue、CheckRedirect
func doStreamLoad(streamLoadURL, user, pass string, rows any) (loaded int, err error) {
	body, err := json.Marshal(rows)
	if err != nil {
		return 0, err
	}
	req, err := http.NewRequest(http.MethodPut, streamLoadURL, bytes.NewReader(body))
	if err != nil {
		return 0, err
	}
	req.SetBasicAuth(user, pass)
	req.Header.Set("label", fmt.Sprintf("load_%d", time.Now().UnixNano()))
	req.Header.Set("format", "json")
	req.Header.Set("strip_outer_array", "true")
	req.Header.Set("partial_columns", "true")
	req.Header.Set("columns", detailTableColumns)
	req.Header.Set("Expect", "100-continue")
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{
		Timeout: 5 * time.Minute,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	res, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer res.Body.Close()

	respBody, _ := io.ReadAll(res.Body)
	respStr := strings.TrimSpace(string(respBody))
	if res.StatusCode >= 300 && res.StatusCode < 400 {
		location := res.Header.Get("Location")
		return 0, fmt.Errorf("stream load redirected to %s (status %s): %s", location, res.Status, respStr)
	}
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return 0, fmt.Errorf("stream load status %s: %s", res.Status, respStr)
	}
	var loadResp struct {
		Status           string `json:"Status"`
		Message          string `json:"Message"`
		NumberLoadedRows int    `json:"NumberLoadedRows"`
	}
	if err := json.Unmarshal(respBody, &loadResp); err != nil {
		return 0, fmt.Errorf("parse response: %w", err)
	}
	if strings.ToUpper(strings.TrimSpace(loadResp.Status)) != "SUCCESS" {
		log.Printf("stream load response: %s", respStr)
		return 0, fmt.Errorf("stream load Status=%s Message=%s", loadResp.Status, loadResp.Message)
	}
	return loadResp.NumberLoadedRows, nil
}

type OpenApiClient struct {
	BaseURL  string
	AkID     string
	AkSecret string
}

func (c *OpenApiClient) sign(ts int64) string {
	h := md5.New()
	h.Write([]byte(c.AkID))
	h.Write([]byte(c.AkSecret))
	h.Write([]byte(strconv.FormatInt(ts, 10)))
	return hex.EncodeToString(h.Sum(nil))
}

func (c *OpenApiClient) post(path string, form url.Values) ([]byte, error) {
	ts := time.Now().UnixMilli()
	req, err := http.NewRequest(http.MethodPost, c.BaseURL+path, bytes.NewReader([]byte(form.Encode())))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("AccessKey", c.AkID)
	req.Header.Set("TimeStamp", strconv.FormatInt(ts, 10))
	req.Header.Set("Sign", c.sign(ts))
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	return io.ReadAll(resp.Body)
}

func (c *OpenApiClient) postJSON(path string, body []byte) ([]byte, error) {
	ts := time.Now().UnixMilli()
	req, err := http.NewRequest(http.MethodPost, c.BaseURL+path, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("AccessKey", c.AkID)
	req.Header.Set("TimeStamp", strconv.FormatInt(ts, 10))
	req.Header.Set("Sign", c.sign(ts))
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	out, _ := io.ReadAll(resp.Body)
	var generic struct {
		Code    int             `json:"code"`
		Message string          `json:"message"`
		Success bool            `json:"success"`
		Data    json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(out, &generic); err != nil {
		return nil, err
	}
	if !generic.Success {
		return nil, fmt.Errorf("code=%d message=%s data=%s", generic.Code, generic.Message, string(out))
	}
	return out, nil
}

func (c *OpenApiClient) FindSku(model, brand, encapsulation string) ([]byte, error) {
	form := url.Values{}
	form.Set("model", model)
	form.Set("brand", brand)
	form.Set("encapsulation", encapsulation)
	return c.post("/findSku", form)
}

func (c *OpenApiClient) MaterialCodeList(startTime, endTime string) ([]byte, error) {
	form := url.Values{}
	form.Set("startTime", startTime)
	form.Set("endTime", endTime)
	return c.post("/materialCodeList", form)
}

func (c *OpenApiClient) ListByPageAll(componentsList []ComponentQuery) ([]byte, error) {
	body, err := json.Marshal(componentsList)
	if err != nil {
		return nil, err
	}
	return c.postJSON("/listByPageAll", body)
}
