package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type componentDetailInput struct {
	ID string
}

type componentDetailRow struct {
	ID                 string  `json:"id"`
	CatID              *string `json:"cat_id"`
	Name               *string `json:"name"`
	Picture            *string `json:"picture"`
	BrandName          *string `json:"brand_name"`
	BrandID            *string `json:"brand_id"`
	Supplier           *string `json:"supplier"`
	ExtendedAttributes *string `json:"extended_attributes"`
	Description        *string `json:"description"`
	Encapsulation      *string `json:"encapsulation"`
	DataSheet          *string `json:"data_sheet"`
	ECCN               *string `json:"eccn"`
}

type componentDetailResponse struct {
	Success bool           `json:"success"`
	Code    int            `json:"code"`
	Message string         `json:"message"`
	Data    map[string]any `json:"data"`
}

func runComponentDetailImport(cfg config) error {
	if cfg.Authorization == "" {
		return errors.New("missing Authorization")
	}
	if cfg.SkuDetail.APIURL == "" {
		return errors.New("missing component detail api url")
	}

	ddl := buildComponentDetailDDL(cfg.StarrocksDB, cfg.SkuDetail.TargetTable)
	log.Println("table ddl:\n" + ddl)

	if cfg.StarrocksDSN != "" {
		if err := ensureTable(cfg, ddl); err != nil {
			return err
		}
	}

	if cfg.SkuDetail.StreamLoadURL == "" {
		return errors.New("missing component detail stream load url")
	}

	lastID := cfg.ComponentDetailStartID
	if lastID != "" {
		log.Printf("component_detail resuming after id %q (key-set pagination)", lastID)
	}
	var endAt time.Time
	var processedTotal int
	for {
		if !endAt.IsZero() && time.Now().After(endAt) {
			log.Printf("component_detail test window reached, stopping after id %q", lastID)
			break
		}
		inputs, err := fetchComponentInputsBatch(cfg, lastID, cfg.SkuDetail.DBBatchSize)
		if err != nil {
			return err
		}
		if len(inputs) == 0 {
			break
		}

		rows, err := fetchComponentDetailRows(cfg, inputs, cfg.SkuDetail.WorkerCount, cfg.SkuDetail.WorkerQPS, cfg.SkuDetail.StatsInterval)
		if err != nil {
			return err
		}
		if err := streamLoad(cfg, cfg.SkuDetail.StreamLoadURL,
			"id,cat_id,name,picture,brand_name,brand_id,supplier,extended_attributes,description,encapsulation,data_sheet,eccn",
			rows); err != nil {
			return err
		}

		lastID = inputs[len(inputs)-1].ID
		processedTotal += len(inputs)
		log.Printf("processed %d rows, last_id=%q", processedTotal, lastID)
	}

	return nil
}

func buildComponentDetailDDL(db, table string) string {
	return fmt.Sprintf(
		"CREATE TABLE IF NOT EXISTS `%s`.`%s` (\n"+
			"  `id` VARCHAR(64) NOT NULL COMMENT '组件ID',\n"+
			"  `cat_id` VARCHAR(64) NULL COMMENT '分类ID',\n"+
			"  `name` VARCHAR(256) NULL COMMENT '名称/型号',\n"+
			"  `picture` VARCHAR(512) NULL COMMENT '图片',\n"+
			"  `brand_name` VARCHAR(256) NULL COMMENT '品牌名称',\n"+
			"  `brand_id` VARCHAR(64) NULL COMMENT '品牌ID',\n"+
			"  `supplier` VARCHAR(256) NULL COMMENT '供应商',\n"+
			"  `extended_attributes` STRING NULL COMMENT '扩展属性',\n"+
			"  `description` STRING NULL COMMENT '描述',\n"+
			"  `encapsulation` VARCHAR(128) NULL COMMENT '封装',\n"+
			"  `data_sheet` STRING NULL COMMENT '数据手册',\n"+
			"  `eccn` VARCHAR(64) NULL COMMENT 'ECCN',\n"+
			"  `create_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '记录入库时间',\n"+
			"  `update_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '记录更新时间（数据更新时手动刷新）'\n"+
			") ENGINE=OLAP\n"+
			"PRIMARY KEY(`id`)\n"+
			"DISTRIBUTED BY HASH(`id`) BUCKETS 8\n"+
			"PROPERTIES (\n"+
			"  \"replication_num\" = \"1\""+
			");",
		db, table,
	)
}

// fetchComponentInputsBatch 使用基于 id 的游标（key-set）分页拉取"待补"id：
//   - 严格 ORDER BY id ASC，配合 id > lastID 推进游标，避免分布式表 LIMIT/OFFSET 顺序不稳定导致的漏读/重读
//   - 通过 LEFT JOIN 目标 detail 表过滤掉已存在的 id，只返回 detail 表里还没有的 id，避免重复请求 API
//
// lastID 为空时从最小 id 开始遍历。
func fetchComponentInputsBatch(cfg config, lastID string, limit int) ([]componentDetailInput, error) {
	db, err := sql.Open("mysql", cfg.StarrocksDSN)
	if err != nil {
		return nil, err
	}
	defer db.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	query := fmt.Sprintf(
		"SELECT c.id FROM `%s`.`%s` c "+
			"LEFT JOIN `%s`.`%s` d ON c.id = d.id "+
			"WHERE c.id IS NOT NULL AND c.id != '' AND c.id > ? AND d.id IS NULL "+
			"ORDER BY c.id ASC "+
			"LIMIT %d",
		cfg.StarrocksDB,
		cfg.SkuDetail.SourceTable,
		cfg.StarrocksDB,
		cfg.SkuDetail.TargetTable,
		limit,
	)

	rows, err := db.QueryContext(ctx, query, lastID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	results := make([]componentDetailInput, 0, limit)
	for rows.Next() {
		var id sql.NullString
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		if !id.Valid || strings.TrimSpace(id.String) == "" {
			continue
		}
		results = append(results, componentDetailInput{
			ID: strings.TrimSpace(id.String),
		})
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return results, nil
}

func fetchComponentDetailRows(cfg config, inputs []componentDetailInput, workers, perWorkerQPS int, statsInterval time.Duration) ([]componentDetailRow, error) {
	if workers <= 0 {
		workers = 1
	}
	if perWorkerQPS <= 0 {
		perWorkerQPS = 1
	}
	if statsInterval <= 0 {
		statsInterval = 2 * time.Second
	}

	var processed int64
	var processedWindow int64
	jobs := make(chan componentDetailInput)
	results := make(chan componentDetailRow, len(inputs))

	worker := func() {
		ticker := time.NewTicker(time.Second / time.Duration(perWorkerQPS))
		defer ticker.Stop()

		for input := range jobs {
			<-ticker.C
			status, resp, raw, err := callComponentDetail(cfg, input.ID)
			if err != nil {
				log.Printf("component detail fetch failed id=%s status=%d err=%v", input.ID, status, err)
				atomic.AddInt64(&processed, 1)
				atomic.AddInt64(&processedWindow, 1)
				continue
			}
			if !resp.Success || resp.Data == nil {
				log.Printf("component detail response not success id=%s code=%d message=%s raw=%s", input.ID, resp.Code, resp.Message, raw)
				atomic.AddInt64(&processed, 1)
				atomic.AddInt64(&processedWindow, 1)
				continue
			}

			results <- componentDetailRow{
				ID:                 input.ID,
				CatID:              strPtrFromMap(resp.Data, "catId"),
				Name:               strPtrFromMap(resp.Data, "name"),
				Picture:            strPtrFromMap(resp.Data, "picture"),
				BrandName:          strPtrFromMap(resp.Data, "brandName"),
				BrandID:            strPtrFromMap(resp.Data, "brandId"),
				Supplier:           strPtrFromMap(resp.Data, "supplier"),
				ExtendedAttributes: strPtrFromMap(resp.Data, "extendedAttributes"),
				Description:        strPtrFromMap(resp.Data, "description"),
				Encapsulation:      strPtrFromMap(resp.Data, "encapsulation"),
				DataSheet:          strPtrFromMap(resp.Data, "dataSheet"),
				ECCN:               strPtrFromMap(resp.Data, "eccn"),
			}

			atomic.AddInt64(&processed, 1)
			atomic.AddInt64(&processedWindow, 1)
		}
	}

	var wg sync.WaitGroup
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			worker()
		}()
	}

	ticker := time.NewTicker(statsInterval)
	done := make(chan struct{})
	go func() {
		for {
			select {
			case <-ticker.C:
				total := atomic.LoadInt64(&processed)
				window := atomic.SwapInt64(&processedWindow, 0)
				qps := float64(window) / statsInterval.Seconds()
				log.Printf("component_detail processed=%d, window=%d, qps=%.2f", total, window, qps)
			case <-done:
				return
			}
		}
	}()

	go func() {
		defer close(jobs)
		for _, input := range inputs {
			jobs <- input
		}
	}()

	rows := make([]componentDetailRow, 0, len(inputs))
	go func() {
		wg.Wait()
		close(results)
	}()

	for row := range results {
		rows = append(rows, row)
	}

	close(done)
	ticker.Stop()

	log.Printf("component_detail insert_rows=%d", len(rows))
	return rows, nil
}

func callComponentDetail(cfg config, id string) (int, componentDetailResponse, string, error) {
	apiURL := fmt.Sprintf("%s/%s", strings.TrimRight(cfg.SkuDetail.APIURL, "/"), id)
	req, err := http.NewRequest(http.MethodGet, apiURL, nil)
	if err != nil {
		return 0, componentDetailResponse{}, "", err
	}
	req.Header.Set("Authorization", cfg.Authorization)

	client := &http.Client{Timeout: 60 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return 0, componentDetailResponse{}, "", err
	}
	defer res.Body.Close()

	respBody, err := io.ReadAll(res.Body)
	if err != nil {
		return res.StatusCode, componentDetailResponse{}, "", err
	}

	raw := strings.TrimSpace(string(respBody))
	var apiResp componentDetailResponse
	if err := json.Unmarshal(respBody, &apiResp); err != nil {
		return res.StatusCode, componentDetailResponse{}, raw, err
	}
	return res.StatusCode, apiResp, raw, nil
}

func strPtrFromMap(item map[string]any, key string) *string {
	if item == nil {
		return nil
	}
	value, ok := item[key]
	if !ok || value == nil {
		return nil
	}
	switch v := value.(type) {
	case string:
		trimmed := strings.TrimSpace(v)
		if trimmed == "" || strings.EqualFold(trimmed, "null") {
			return nil
		}
		return &trimmed
	default:
		encoded, err := json.Marshal(v)
		if err != nil {
			return nil
		}
		str := string(encoded)
		return &str
	}
}

func strPtrIfNotEmpty(value string) *string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}
