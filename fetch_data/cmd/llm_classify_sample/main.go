package main

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

type sampleItem struct {
	ID        int64  `json:"id"`
	Partno    string `json:"partno"`
	Brand     string `json:"brand"`
	Category  string `json:"category,omitempty"`
	Category2 string `json:"category2,omitempty"`
	SQLL2     string `json:"sql_l2,omitempty"`
	SQLL3     string `json:"sql_l3,omitempty"`
}

type classifyResult struct {
	ID         int64   `json:"id"`
	Partno     string  `json:"partno,omitempty"`
	Brand      string  `json:"brand,omitempty"`
	L2Code     string  `json:"l2_code"`
	L3Code     string  `json:"l3_code"`
	Confidence float64 `json:"confidence"`
	Evidence   string  `json:"evidence"`
}

type resultEnvelope struct {
	Results []classifyResult `json:"results"`
}

type usage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
	TotalTokens      int `json:"total_tokens"`
}

type batchLog struct {
	Index       int       `json:"batch_index"`
	ItemCount   int       `json:"item_count"`
	LatencyMs   int64     `json:"latency_ms"`
	Usage       usage     `json:"usage"`
	StatusCode  int       `json:"status_code"`
	Error       string    `json:"error,omitempty"`
	RawResponse string    `json:"raw_response"`
	Confidences []float64 `json:"-"`
}

type outputFile struct {
	Model          string           `json:"model"`
	BaseURL        string           `json:"base_url"`
	SampleMode     string           `json:"sample_mode"`        // "category" or "l3"
	Category       string           `json:"category,omitempty"` // filled when sample_mode=category
	L3Code         string           `json:"l3_code,omitempty"`  // filled when sample_mode=l3
	L2Table        string           `json:"l2_table,omitempty"`
	BatchSize      int              `json:"batch_size"`
	CreatedAt      string           `json:"created_at"`
	Items          []sampleItem     `json:"items"`
	Results        []classifyResult `json:"results,omitempty"`
	Batches        []batchLog       `json:"batches"`
	TotalTokens    usage            `json:"total_tokens"`
	TotalLatencyMs int64            `json:"total_latency_ms"`
}

type chatRequest struct {
	Model       string        `json:"model"`
	Messages    []chatMessage `json:"messages"`
	Temperature float64       `json:"temperature"`
	MaxTokens   int           `json:"max_tokens,omitempty"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatResponse struct {
	Choices []struct {
		Message chatMessage `json:"message"`
	} `json:"choices"`
	Usage usage `json:"usage"`
	Error *struct {
		Message string `json:"message"`
		Type    string `json:"type"`
	} `json:"error,omitempty"`
}

const systemPrompt = `你是电子元器件/IC 分类专家。只根据 partno 和 brand 做独立判断，不要相信输入 category 一定正确。
如果你不认识该具体型号或同系列型号，输出 unknown，confidence <= 0.3，不要靠型号字符串硬猜。

候选分类只能使用以下枚举：
- l2_code=voltage_regulator, l3_code=ldo_regulator: LDO/线性稳压器/低压差稳压器
- l2_code=voltage_regulator, l3_code=dcdc_switching: DC-DC 开关稳压器/控制器/模块（含 charge pump、PFC 控制器）；但 AC-DC 归 out_of_scope
- l2_code=bms_supervisor, l3_code=battery_charger: 电池充电/电池管理/保护
- l2_code=bms_supervisor, l3_code=voltage_ref: 电压基准源（如 TL431/REF02/ADR 系列）
- l2_code=bms_supervisor, l3_code=supervisor_reset: 电源电压监控/复位/看门狗
- l2_code=driver_ic, l3_code=gate_driver: MOSFET/IGBT 栅极驱动器、半桥/全桥/同步整流驱动器
- l2_code=driver_ic, l3_code=motor_driver: 电机驱动器（有刷/无刷/步进），以及 H-bridge power driver (TEC/螺线管/PWM 电流桥)
- l2_code=driver_ic, l3_code=led_driver: LED 驱动/LED 控制（恒流 LED driver）
- l2_code=out_of_scope, l3_code=out_of_scope: 非上述范围。典型：AC-DC、Power-distribution/load switch (TPS205x/TPS20xx/TPS22xx PCMCIA 等)、Hot-swap controller、Ideal diode、Ground fault interrupter、CCFL/Ballast 控制器、Current monitor、压电变压器控制器、SCSI/Bus terminator、Smart power MOSFET 本身（BTS/OMNIFET）
- l2_code=unknown, l3_code=unknown: 仅凭 partno+brand 无法可靠判断

严格输出 JSON 对象，不要 Markdown 围栏，不要解释。格式：
{"results":[{"id":123,"partno":"...","brand":"...","l2_code":"...","l3_code":"...","confidence":0.0,"evidence":"<=40字，型号/系列依据或 unknown 原因"}]}`

func main() {
	var (
		baseURL   = flag.String("base", envOr("MODEL_LAKE_BASE_URL", "http://192.168.19.21:11010/model-lake/unified/v1"), "OpenAI-compatible model lake base URL")
		model     = flag.String("model", envOr("MODEL_LAKE_MODEL", "azure_openai/gpt-4o-mini"), "model lake model id")
		dsn       = flag.String("dsn", os.Getenv("STARROCKS_DSN"), "StarRocks/MySQL DSN, e.g. user:pass@tcp(host:9030)/")
		category  = flag.String("category", "", "icpdf category to sample (mutually exclusive with -l3)")
		l3Code    = flag.String("l3", "", "sample from given l3_code; requires -l2-table")
		l2Table   = flag.String("l2-table", "", "dwd l2 table name, e.g. dwd_l2_voltage_regulator (used with -l3)")
		limit     = flag.Int("limit", 100, "number of rows to sample")
		batchSize = flag.Int("batch-size", 25, "items per LLM request (smaller = fewer timeouts)")
		maxTokens = flag.Int("max-tokens", 4096, "chat completion max_tokens per batch")
		timeout   = flag.Duration("timeout", 180*time.Second, "HTTP timeout per batch")
		outPath   = flag.String("out", "", "output JSON path (required)")
	)
	flag.Parse()

	if strings.TrimSpace(*dsn) == "" {
		log.Fatal("missing -dsn or STARROCKS_DSN; example: root:password@tcp(192.168.19.21:9030)/")
	}
	if strings.TrimSpace(*outPath) == "" {
		log.Fatal("missing -out")
	}
	if (*category == "" && *l3Code == "") || (*category != "" && *l3Code != "") {
		log.Fatal("exactly one of -category or -l3 must be set")
	}
	if *l3Code != "" && *l2Table == "" {
		log.Fatal("-l3 requires -l2-table (e.g. dwd_l2_voltage_regulator)")
	}

	var (
		items []sampleItem
		err   error
		mode  string
	)
	if *category != "" {
		mode = "category"
		items, err = loadByCategory(*dsn, *category, *limit)
	} else {
		mode = "l3"
		items, err = loadByL3(*dsn, *l2Table, *l3Code, *limit)
	}
	if err != nil {
		log.Fatalf("load samples: %v", err)
	}
	if len(items) == 0 {
		log.Fatalf("no rows found")
	}

	out := outputFile{
		Model:      *model,
		BaseURL:    *baseURL,
		SampleMode: mode,
		Category:   *category,
		L3Code:     *l3Code,
		L2Table:    *l2Table,
		BatchSize:  *batchSize,
		CreatedAt:  time.Now().Format(time.RFC3339),
		Items:      items,
	}

	// Split items into batches
	var allResults []classifyResult
	start := time.Now()
	for i := 0; i < len(items); i += *batchSize {
		end := i + *batchSize
		if end > len(items) {
			end = len(items)
		}
		slice := items[i:end]
		batchStart := time.Now()

		raw, u, statusCode, callErr := classify(*baseURL, *model, slice, *maxTokens, *timeout)
		latency := time.Since(batchStart)

		bl := batchLog{
			Index:       i / *batchSize,
			ItemCount:   len(slice),
			LatencyMs:   latency.Milliseconds(),
			Usage:       u,
			StatusCode:  statusCode,
			RawResponse: raw,
		}
		if callErr != nil {
			bl.Error = callErr.Error()
			log.Printf("batch %d failed: %v", bl.Index, callErr)
		} else {
			parsed, parseErr := parseResults(raw)
			if parseErr != nil {
				bl.Error = fmt.Sprintf("parse: %v", parseErr)
				log.Printf("batch %d parse failed: %v", bl.Index, parseErr)
			} else {
				allResults = append(allResults, parsed...)
			}
		}
		out.Batches = append(out.Batches, bl)
		out.TotalTokens.PromptTokens += u.PromptTokens
		out.TotalTokens.CompletionTokens += u.CompletionTokens
		out.TotalTokens.TotalTokens += u.TotalTokens
		log.Printf("batch %d/%d done: %d items, %dms, tokens=%d+%d",
			bl.Index+1, (len(items)+*batchSize-1)/(*batchSize),
			len(slice), latency.Milliseconds(), u.PromptTokens, u.CompletionTokens)
	}
	out.TotalLatencyMs = time.Since(start).Milliseconds()
	out.Results = allResults

	if err := writeJSON(*outPath, out); err != nil {
		log.Fatalf("write output: %v", err)
	}
	log.Printf("done: %d samples, parsed %d results, total %dms, tokens %d+%d=%d, wrote %s",
		len(items), len(allResults), out.TotalLatencyMs,
		out.TotalTokens.PromptTokens, out.TotalTokens.CompletionTokens, out.TotalTokens.TotalTokens,
		*outPath)
}

func loadByCategory(dsn, category string, limit int) ([]sampleItem, error) {
	if limit <= 0 {
		return nil, fmt.Errorf("limit must be positive, got %d", limit)
	}
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, err
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		return nil, err
	}
	q := fmt.Sprintf(`
SELECT id,
       COALESCE(partno, '') AS partno,
       COALESCE(brandshort, '') AS brand,
       COALESCE(category, '') AS category,
       COALESCE(category2, '') AS category2
FROM dwd.dwd_icpdf_component_param
WHERE category = ?
  AND partno IS NOT NULL AND partno <> ''
ORDER BY id
LIMIT %d`, limit)
	rows, err := db.Query(q, category)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []sampleItem
	for rows.Next() {
		var it sampleItem
		if err := rows.Scan(&it.ID, &it.Partno, &it.Brand, &it.Category, &it.Category2); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

// loadByL3 samples 'limit' rows whose sql classification is (l2_table, l3_code).
// Sampling uses rand() for representativeness.
func loadByL3(dsn, l2Table, l3Code string, limit int) ([]sampleItem, error) {
	if limit <= 0 {
		return nil, fmt.Errorf("limit must be positive, got %d", limit)
	}
	if !reValidTable.MatchString(l2Table) {
		return nil, fmt.Errorf("invalid l2 table name: %q", l2Table)
	}
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, err
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		return nil, err
	}
	// Use l2 table to filter by l3 (that's where SQL classification lives for its L2),
	// join back to param for brand/category context.
	q := fmt.Sprintf(`
SELECT l.id,
       COALESCE(l.partno, '')      AS partno,
       COALESCE(l.brand, '')       AS brand,
       COALESCE(p.category, '')    AS category,
       COALESCE(p.category2, '')   AS category2,
       COALESCE(l.l2_code, '')     AS sql_l2,
       COALESCE(l.l3_code, '')     AS sql_l3
FROM dwd.%s l
JOIN dwd.dwd_icpdf_component_param p ON p.id = l.id
WHERE l.l3_code = ?
  AND l.partno IS NOT NULL AND l.partno <> ''
ORDER BY l.id
LIMIT %d`, l2Table, limit)
	rows, err := db.Query(q, l3Code)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []sampleItem
	for rows.Next() {
		var it sampleItem
		if err := rows.Scan(&it.ID, &it.Partno, &it.Brand, &it.Category, &it.Category2, &it.SQLL2, &it.SQLL3); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

var reValidTable = regexp.MustCompile(`^[A-Za-z0-9_]+$`)

func classify(baseURL, model string, items []sampleItem, maxTokens int, timeout time.Duration) (string, usage, int, error) {
	// Send only partno/brand to the model (force independence from icpdf category).
	lean := make([]map[string]any, len(items))
	for i, it := range items {
		lean[i] = map[string]any{"id": it.ID, "partno": it.Partno, "brand": it.Brand}
	}
	payload, err := json.Marshal(lean)
	if err != nil {
		return "", usage{}, 0, err
	}

	reqBody := chatRequest{
		Model:       model,
		Temperature: 0,
		MaxTokens:   maxTokens,
		Messages: []chatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: fmt.Sprintf("请批量分类以下 %d 个器件。只根据 partno+brand 判断。输入 JSON:\n%s", len(items), string(payload))},
		},
	}
	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", usage{}, 0, err
	}
	url := strings.TrimRight(baseURL, "/") + "/chat/completions"
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", usage{}, 0, err
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: timeout}
	resp, err := client.Do(req)
	if err != nil {
		return "", usage{}, 0, err
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", usage{}, resp.StatusCode, err
	}
	var decoded chatResponse
	if err := json.Unmarshal(respBody, &decoded); err != nil {
		return "", usage{}, resp.StatusCode, fmt.Errorf("decode: %w; body=%s", err, string(respBody))
	}
	if decoded.Error != nil {
		return "", decoded.Usage, resp.StatusCode, fmt.Errorf("%s: %s", decoded.Error.Type, decoded.Error.Message)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", decoded.Usage, resp.StatusCode, fmt.Errorf("status %d: %s", resp.StatusCode, string(respBody))
	}
	if len(decoded.Choices) == 0 {
		return "", decoded.Usage, resp.StatusCode, errors.New("no choices")
	}
	return decoded.Choices[0].Message.Content, decoded.Usage, resp.StatusCode, nil
}

func parseResults(raw string) ([]classifyResult, error) {
	clean := stripCodeFence(strings.TrimSpace(raw))
	var envelope resultEnvelope
	if err := json.Unmarshal([]byte(clean), &envelope); err != nil {
		return nil, err
	}
	return envelope.Results, nil
}

func stripCodeFence(s string) string {
	re := regexp.MustCompile("(?s)^```(?:json)?\\s*(.*?)\\s*```$")
	if m := re.FindStringSubmatch(s); len(m) == 2 {
		return strings.TrimSpace(m[1])
	}
	return s
}

func writeJSON(path string, v any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(b, '\n'), 0o644)
}

func envOr(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}
