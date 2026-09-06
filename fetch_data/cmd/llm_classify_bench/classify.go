package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"
)

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatRequest struct {
	Model       string        `json:"model"`
	Messages    []chatMessage `json:"messages"`
	Temperature float64       `json:"temperature"`
	MaxTokens   int           `json:"max_tokens,omitempty"`
}

type chatUsage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
	TotalTokens      int `json:"total_tokens"`
}

type chatResponse struct {
	ID      string       `json:"id"`
	Model   string       `json:"model"`
	Channel string       `json:"channel,omitempty"`
	Usage   chatUsage    `json:"usage"`
	Choices []chatChoice `json:"choices"`
	Error   *chatError   `json:"error,omitempty"`
}

type chatChoice struct {
	Index        int         `json:"index"`
	Message      chatMessage `json:"message"`
	FinishReason string      `json:"finish_reason,omitempty"`
}

type chatError struct {
	Message string `json:"message"`
	Type    string `json:"type"`
}

type ClassifyResult struct {
	ID             int64   `json:"id"`
	Partno         string  `json:"partno,omitempty"`
	Brand          string  `json:"brand,omitempty"`
	L2Code         string  `json:"l2_code"`
	L3Code         string  `json:"l3_code"`
	Confidence     float64 `json:"confidence"`
	Evidence       string  `json:"evidence,omitempty"`
	SeenInTraining *bool   `json:"seen_in_training,omitempty"`
}

type BatchStat struct {
	BatchIndex       int           `json:"batch_index"`
	Size             int           `json:"size"`
	StartedAt        time.Time     `json:"started_at"`
	Duration         time.Duration `json:"duration_ms"`
	PromptTokens     int           `json:"prompt_tokens"`
	CompletionTokens int           `json:"completion_tokens"`
	TotalTokens      int           `json:"total_tokens"`
	Error            string        `json:"error,omitempty"`
	Parsed           int           `json:"parsed"`
}

type RunOutput struct {
	Model        string           `json:"model"`
	BaseURL      string           `json:"base_url"`
	BatchSize    int              `json:"batch_size"`
	Workers      int              `json:"workers"`
	TotalItems   int              `json:"total_items"`
	StartedAt    time.Time        `json:"started_at"`
	FinishedAt   time.Time        `json:"finished_at"`
	WallDuration time.Duration    `json:"wall_duration_ms"`
	TotalUsage   chatUsage        `json:"total_usage"`
	Batches      []BatchStat      `json:"batches"`
	Results      []ClassifyResult `json:"results"`
}

const systemPrompt = `你是电子元器件/IC 分类专家。基于 partno+brand+note 给出 L2+L3。
候选（严格使用这些字符串，不要发明新代码）：

voltage_regulator:
  ldo_regulator       LDO/线性稳压器/低压差稳压器
  dcdc_switching      DC-DC 开关稳压器/控制器/模块 / PFC 控制器 / charge pump 电压转换器 / 集成 SMPS IC
bms_supervisor:
  battery_charger     电池充电/充电管理/电池保护
  voltage_ref         电压基准源（TL431, REF0x, ADR5xx 等精密基准）
  supervisor_reset    电源电压监控/复位 IC/看门狗（Supply Voltage Supervisor）
driver_ic:
  gate_driver         MOSFET/IGBT 栅极驱动器、半桥/全桥栅极驱动
  motor_driver        电机驱动（含 H-bridge PWM power driver，如 TI DRV59x 系列）
  led_driver          LED 驱动/LED 控制器（恒流源驱动 LED）
out_of_scope          不属于上述 PMIC/驱动范围，包括但不限于：
                      - Load switch / power-distribution switch / high-side / low-side power switch / PCMCIA / USB 开关
                      - Hot-swap controller / 热插拔控制器
                      - Ideal diode controller / 理想二极管
                      - 电流/功率监视器
                      - CCFL / 荧光灯镇流控制器（若是）
                      - 自保护 MOSFET 本体（OMNIFET 等，器件本身不是 IC）
                      - SCSI 终结器 / 总线终端器
                      - AC-DC 转换器（完整，非 PFC 前级）
                      - Alternator 调节器 / 压电变压器控制器等小众专用件
unknown               partno 未知、训练语料未覆盖，且没有 note 可用

决策优先级：
 1. prajson/note 里明确参数（"Step-Down","LDO","MOSFET Driver","CCFL","Power-Distribution Switch"）> 命名前缀猜测
 2. 若 note 指明是 PFC / 功率因数控制器 → dcdc_switching
 3. "高效 PWM power driver / H-Bridge" → motor_driver（不是 gate_driver，也不是 led_driver）
 4. PCMCIA / ExpressCard / PC Card / USB 开关 / "Power-Interface Switch" → out_of_scope
 5. 发电机调节器 / 纹波衰减模块 / 压电变压器控制器 → out_of_scope
 6. 自认不认识该 partno 且 note 也含糊 → unknown, confidence<=0.3

输出严格 JSON（不要 Markdown）：
{"results":[{"id":<int>,"l2_code":"...","l3_code":"...","confidence":0.xx,"evidence":"<=40字","seen_in_training":true|false}]}
`

func userPromptFor(items []SampleItem) string {
	// 每行一条紧凑输入；包含 note_cn 作为最重要的 datasheet 摘要线索
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("请分类以下 %d 个器件。输入数组（id / partno / brand / note）：\n", len(items)))
	for _, it := range items {
		note := it.NoteCN
		if note == "" {
			note = it.Note
		}
		if len(note) > 120 {
			note = note[:120]
		}
		sb.WriteString(fmt.Sprintf(`{"id":%d,"partno":%q,"brand":%q,"note":%q}`+"\n",
			it.ID, it.Partno, it.Brand, note))
	}
	return sb.String()
}

var fencedJSON = regexp.MustCompile("(?s)^```(?:json)?\\s*(.*?)\\s*```$")

func stripFence(s string) string {
	s = strings.TrimSpace(s)
	if m := fencedJSON.FindStringSubmatch(s); len(m) == 2 {
		return strings.TrimSpace(m[1])
	}
	return s
}

func parseResults(raw string) ([]ClassifyResult, error) {
	var env struct {
		Results []ClassifyResult `json:"results"`
	}
	if err := json.Unmarshal([]byte(stripFence(raw)), &env); err != nil {
		return nil, err
	}
	return env.Results, nil
}

// callOnce 发送一次 chat/completions 请求，返回原始 content + usage + latency
func callOnce(ctx context.Context, baseURL, model string, items []SampleItem, maxTokens int, timeout time.Duration) (string, chatUsage, time.Duration, error) {
	req := chatRequest{
		Model:       model,
		Temperature: 0,
		MaxTokens:   maxTokens,
		Messages: []chatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: userPromptFor(items)},
		},
	}
	body, _ := json.Marshal(req)
	httpCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	url := strings.TrimRight(baseURL, "/") + "/chat/completions"
	httpReq, err := http.NewRequestWithContext(httpCtx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", chatUsage{}, 0, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	start := time.Now()
	client := &http.Client{Timeout: timeout}
	resp, err := client.Do(httpReq)
	if err != nil {
		return "", chatUsage{}, time.Since(start), err
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", chatUsage{}, time.Since(start), err
	}
	dur := time.Since(start)

	var decoded chatResponse
	if err := json.Unmarshal(respBody, &decoded); err != nil {
		return "", chatUsage{}, dur, fmt.Errorf("decode chat response: %w; body=%s", err, string(respBody))
	}
	if decoded.Error != nil {
		return "", chatUsage{}, dur, fmt.Errorf("%s: %s", decoded.Error.Type, decoded.Error.Message)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", chatUsage{}, dur, fmt.Errorf("status %d: %s", resp.StatusCode, string(respBody))
	}
	if len(decoded.Choices) == 0 {
		return "", chatUsage{}, dur, errors.New("no choices")
	}
	return decoded.Choices[0].Message.Content, decoded.Usage, dur, nil
}

// RunBench 批量并发分类全量 items
func RunBench(ctx context.Context, baseURL, model string, items []SampleItem,
	batchSize, workers, maxTokens int, timeout time.Duration, retries int) RunOutput {

	out := RunOutput{
		Model:      model,
		BaseURL:    baseURL,
		BatchSize:  batchSize,
		Workers:    workers,
		TotalItems: len(items),
		StartedAt:  time.Now(),
	}
	if batchSize <= 0 {
		batchSize = 50
	}
	if workers <= 0 {
		workers = 4
	}

	type batchJob struct {
		idx  int
		from int
		to   int
	}
	jobs := make(chan batchJob)
	var mu sync.Mutex
	resultsByBatch := make([][]ClassifyResult, 0)
	batchStats := make([]BatchStat, 0)

	// 预计算 batch 数
	var batchCount int
	for i := 0; i < len(items); i += batchSize {
		batchCount++
	}
	resultsByBatch = make([][]ClassifyResult, batchCount)
	batchStats = make([]BatchStat, batchCount)

	var wg sync.WaitGroup
	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := range jobs {
				stat := BatchStat{BatchIndex: j.idx, Size: j.to - j.from, StartedAt: time.Now()}
				var lastErr error
				var content string
				var usage chatUsage
				var dur time.Duration
				for attempt := 0; attempt <= retries; attempt++ {
					content, usage, dur, lastErr = callOnce(ctx, baseURL, model, items[j.from:j.to], maxTokens, timeout)
					if lastErr == nil {
						break
					}
					time.Sleep(time.Duration(500*(attempt+1)) * time.Millisecond)
				}
				stat.Duration = dur
				stat.PromptTokens = usage.PromptTokens
				stat.CompletionTokens = usage.CompletionTokens
				stat.TotalTokens = usage.TotalTokens
				if lastErr != nil {
					stat.Error = lastErr.Error()
					mu.Lock()
					batchStats[j.idx] = stat
					mu.Unlock()
					continue
				}
				results, perr := parseResults(content)
				if perr != nil {
					stat.Error = "parse: " + perr.Error()
				}
				stat.Parsed = len(results)
				mu.Lock()
				batchStats[j.idx] = stat
				resultsByBatch[j.idx] = results
				mu.Unlock()
			}
		}()
	}

	idx := 0
	for i := 0; i < len(items); i += batchSize {
		to := i + batchSize
		if to > len(items) {
			to = len(items)
		}
		jobs <- batchJob{idx: idx, from: i, to: to}
		idx++
	}
	close(jobs)
	wg.Wait()

	out.FinishedAt = time.Now()
	out.WallDuration = out.FinishedAt.Sub(out.StartedAt)
	out.Batches = batchStats
	for _, st := range batchStats {
		out.TotalUsage.PromptTokens += st.PromptTokens
		out.TotalUsage.CompletionTokens += st.CompletionTokens
		out.TotalUsage.TotalTokens += st.TotalTokens
	}
	for _, br := range resultsByBatch {
		out.Results = append(out.Results, br...)
	}
	return out
}
