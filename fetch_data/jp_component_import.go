package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const (
	componentCompleteFile = "component_complete.txt"
	componentFailedFile   = "component_failed_pages.txt"
)

var (
	completePageFileMu sync.Mutex
	failedPageFileMu   sync.Mutex
)

// appendFailedPage 将 fetch / load 失败的页码追加到 component_failed_pages.txt，
// 方便下次用 -component-missing-pages-file=component_failed_pages.txt 定向补跑
func appendFailedPage(page int) {
	failedPageFileMu.Lock()
	defer failedPageFileMu.Unlock()
	f, err := os.OpenFile(componentFailedFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Printf("failed to append page %d to %s: %v", page, componentFailedFile, err)
		return
	}
	defer f.Close()
	if _, err := fmt.Fprintln(f, page); err != nil {
		log.Printf("failed to write page %d to %s: %v", page, componentFailedFile, err)
	}
}

// componentRateLimit 返回 component 任务的请求间隔，优先使用 Component.RateLimit
func componentRateLimit(cfg *config) time.Duration {
	if cfg.Component.RateLimit > 0 {
		return cfg.Component.RateLimit
	}
	return cfg.RateLimit
}

// appendCompletedPage 将成功写入的页码追加写入 component_complete.txt（用于断点续跑：重启时剔除已完成的页）
func appendCompletedPage(page int) {
	completePageFileMu.Lock()
	defer completePageFileMu.Unlock()
	f, err := os.OpenFile(componentCompleteFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Printf("failed to append page %d to %s: %v", page, componentCompleteFile, err)
		return
	}
	defer f.Close()
	if _, err := fmt.Fprintln(f, page); err != nil {
		log.Printf("failed to write page %d to %s: %v", page, componentCompleteFile, err)
	}
}

// loadCompletedPagesFromFile 从 component_complete.txt 读取已完成的页码集合（文件不存在或为空则返回空集合）
func loadCompletedPagesFromFile(path string) (map[int]struct{}, error) {
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	defer f.Close()
	done := make(map[int]struct{})
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		n, err := strconv.Atoi(line)
		if err != nil || n < 1 {
			continue
		}
		done[n] = struct{}{}
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return done, nil
}

type componentListResponse struct {
	Success bool   `json:"success"`
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		Total       int             `json:"total"`
		Pages       int             `json:"pages"`
		Size        int             `json:"size"`
		CurrentPage int             `json:"currentPage"`
		Rows        []componentItem `json:"rows"`
	} `json:"data"`
}

type flexibleString string

func (fs *flexibleString) UnmarshalJSON(data []byte) error {
	var v interface{}
	if err := json.Unmarshal(data, &v); err != nil {
		return err
	}
	switch val := v.(type) {
	case string:
		*fs = flexibleString(val)
	case bool:
		if val {
			*fs = "true"
		} else {
			*fs = "false"
		}
	case nil:
		*fs = ""
	default:
		*fs = flexibleString(fmt.Sprintf("%v", val))
	}
	return nil
}

func (fs flexibleString) String() string {
	return string(fs)
}

func (fs flexibleString) ToNullableString() *string {
	s := fs.String()
	if s == "" {
		return nil
	}
	return &s
}

type componentItem struct {
	ID                 string         `json:"id"`
	CatID              *string        `json:"catId"`
	Name               *string        `json:"name"`
	Picture            *string        `json:"picture"`
	BrandName          *string        `json:"brandName"`
	BrandID            *string        `json:"brandId"`
	Supplier           *string        `json:"supplier"`
	ExtendedAttributes *string        `json:"extendedAttributes"`
	Description        *string        `json:"description"`
	Encapsulation      *string        `json:"encapsulation"`
	DataSheet          *string        `json:"dataSheet"`
	ECCN               flexibleString `json:"eccn"`
}

type componentRow struct {
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

func runComponentImport(cfg *config) error {
	if cfg.Component.MissingPagesFile != "" {
		return runComponentImportFromMissingPagesFile(cfg)
	}
	return runComponentImportFullRange(cfg)
}

// runComponentImportFromMissingPagesFile 从缺失页码文件读取待爬页，剔除 component_complete.txt 中已完成的页后爬取并入库；成功一页追加到 component_complete.txt，支持重复启动断点续跑
func runComponentImportFromMissingPagesFile(cfg *config) error {
	pages, err := loadPageNumbersFromFile(cfg.Component.MissingPagesFile)
	if err != nil {
		return err
	}
	if len(pages) == 0 {
		log.Printf("component missing pages file %q has no valid page numbers, nothing to do", cfg.Component.MissingPagesFile)
		return nil
	}

	completed, err := loadCompletedPagesFromFile(componentCompleteFile)
	if err != nil {
		return fmt.Errorf("load %s: %w", componentCompleteFile, err)
	}
	if completed != nil && len(completed) > 0 {
		remaining := make([]int, 0, len(pages))
		for _, p := range pages {
			if _, ok := completed[p]; !ok {
				remaining = append(remaining, p)
			}
		}
		pages = remaining
		log.Printf("component: %d pages already in %s, %d remaining to crawl", len(completed), componentCompleteFile, len(pages))
	}
	if len(pages) == 0 {
		log.Printf("component: all pages from %q are already completed, nothing to do", cfg.Component.MissingPagesFile)
		return nil
	}

	log.Printf("component will crawl %d pages from file %q (excluding completed in %s)", len(pages), cfg.Component.MissingPagesFile, componentCompleteFile)

	ddl := buildComponentDDL(cfg.StarrocksDB, cfg.Component.Table)
	log.Println("table ddl:\n" + ddl)

	if cfg.StarrocksDSN != "" {
		if err := ensureTable(*cfg, ddl); err != nil {
			return err
		}
	}

	if cfg.Component.StreamLoadURL == "" {
		return fmt.Errorf("missing component stream load url")
	}

	workerCount := 5
	if cfg.Component.WorkerCount > 0 {
		workerCount = cfg.Component.WorkerCount
	}
	totalPages := len(pages)
	var nextIndex int64 = 0

	var wg sync.WaitGroup
	var mu sync.Mutex
	var firstErr error

	for i := 0; i < workerCount; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			for {
				idx := int(atomic.AddInt64(&nextIndex, 1) - 1)
				if idx >= totalPages {
					break
				}
				page := pages[idx]
				if err := refreshTokenIfStale(cfg); err != nil {
					mu.Lock()
					if firstErr == nil {
						firstErr = err
					}
					mu.Unlock()
					log.Printf("component worker %d refresh token failed: %v", workerID, err)
					continue
				}
				time.Sleep(componentRateLimit(cfg))
				resp, err := fetchComponentPage(cfg, page)
				if err != nil {
					if strings.Contains(err.Error(), "502") || strings.Contains(err.Error(), "503") || strings.Contains(err.Error(), "504") {
						log.Printf("component worker %d page %d got server error, waiting 10s: %v", workerID, page, err)
						time.Sleep(10 * time.Second)
					}
					mu.Lock()
					if firstErr == nil {
						firstErr = err
					}
					mu.Unlock()
					log.Printf("component worker %d page %d fetch failed: %v", workerID, page, err)
					appendFailedPage(page)
					continue
				}
				if err := loadComponentPage(*cfg, resp.Data.Rows); err != nil {
					mu.Lock()
					if firstErr == nil {
						firstErr = err
					}
					mu.Unlock()
					log.Printf("component worker %d page %d load failed: %v", workerID, page, err)
					appendFailedPage(page)
					continue
				}
				appendCompletedPage(page)
				log.Printf("component worker %d loaded page %d (%d/%d), appended to %s", workerID, page, idx+1, totalPages, componentCompleteFile)
			}
		}(i)
	}

	wg.Wait()
	if firstErr != nil {
		// 不因单页失败退出，只打日志；失败页未写入 component_complete.txt，下次启动会继续重试
		log.Printf("component import finished with errors (failed pages will be retried on next run): %v", firstErr)
	}
	return nil
}

// loadPageNumbersFromFile 从文件中按行读取页码，每行一个数字，忽略空行和非法行。
// 文件不存在视为"没有需要补跑的页"，返回空切片，让调用方走"无事可做"的正常分支。
func loadPageNumbersFromFile(path string) ([]int, error) {
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			log.Printf("missing pages file %q does not exist, nothing to do", path)
			return nil, nil
		}
		return nil, fmt.Errorf("open missing pages file: %w", err)
	}
	defer f.Close()

	var pages []int
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		n, err := strconv.Atoi(line)
		if err != nil || n < 1 {
			continue
		}
		pages = append(pages, n)
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("read missing pages file: %w", err)
	}
	return pages, nil
}

func runComponentImportFullRange(cfg *config) error {
	firstResp, err := fetchComponentPage(cfg, cfg.Component.PageIndex)
	if err != nil {
		return err
	}
	if len(firstResp.Data.Rows) == 0 {
		return fmt.Errorf("no rows returned from component api")
	}

	log.Printf("component api total=%d pages=%d page_size=%d", firstResp.Data.Total, firstResp.Data.Pages, firstResp.Data.Size)

	ddl := buildComponentDDL(cfg.StarrocksDB, cfg.Component.Table)
	log.Println("table ddl:\n" + ddl)

	if cfg.StarrocksDSN != "" {
		if err := ensureTable(*cfg, ddl); err != nil {
			return err
		}
	}

	if cfg.Component.StreamLoadURL == "" {
		return fmt.Errorf("missing component stream load url")
	}

	if err := loadComponentPage(*cfg, firstResp.Data.Rows); err != nil {
		return err
	}

	workerCount := 5
	if cfg.Component.WorkerCount > 0 {
		workerCount = cfg.Component.WorkerCount
	}
	// 主线程已加载 PageIndex 这一页，worker 应该从 PageIndex+1 开始
	// AddInt64(&nextPage, 1) - 1 返回自增前的值，所以 nextPage 初值就要等于第一页要处理的页号
	startPageNum := cfg.Component.PageIndex + 1
	endPageNum := firstResp.Data.Pages + 1

	var nextPage int64 = int64(startPageNum)

	var wg sync.WaitGroup
	var mu sync.Mutex
	var firstErr error

	for i := 0; i < workerCount; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()

			for {
				page := int(atomic.AddInt64(&nextPage, 1) - 1)

				if page >= endPageNum {
					break
				}

				if err := refreshTokenIfStale(cfg); err != nil {
					mu.Lock()
					if firstErr == nil {
						firstErr = err
					}
					mu.Unlock()
					log.Printf("component worker %d refresh token failed: %v", workerID, err)
					continue
				}
				time.Sleep(componentRateLimit(cfg))
				resp, err := fetchComponentPage(cfg, page)
				if err != nil {
					if strings.Contains(err.Error(), "502") || strings.Contains(err.Error(), "503") || strings.Contains(err.Error(), "504") {
						log.Printf("component worker %d page %d got server error, waiting 10s before continuing: %v", workerID, page, err)
						time.Sleep(10 * time.Second)
					}
					mu.Lock()
					if firstErr == nil {
						firstErr = err
					}
					mu.Unlock()
					log.Printf("component worker %d page %d fetch failed: %v", workerID, page, err)
					appendFailedPage(page)
					continue
				}
				if err := loadComponentPage(*cfg, resp.Data.Rows); err != nil {
					mu.Lock()
					if firstErr == nil {
						firstErr = err
					}
					mu.Unlock()
					log.Printf("component worker %d page %d load failed: %v", workerID, page, err)
					appendFailedPage(page)
					continue
				}
				log.Printf("component worker %d loaded page %d/%d", workerID, page, firstResp.Data.Pages)
			}
		}(i)
	}

	wg.Wait()

	if firstErr != nil {
		return firstErr
	}

	return nil
}

func fetchComponentPage(cfg *config, pageIndex int) (componentListResponse, error) {
	apiURL := fmt.Sprintf("%s?pageSize=%d&pageIndex=%d", cfg.Component.APIURL, cfg.Component.PageSize, pageIndex)
	payload := []byte("{}")

	var lastErr error
	maxRetries := 10
	for attempt := 1; attempt <= maxRetries; attempt++ {
		req, err := http.NewRequest(http.MethodPost, apiURL, bytes.NewReader(payload))
		if err != nil {
			return componentListResponse{}, err
		}
		req.Header.Set("Authorization", cfg.Authorization)
		req.Header.Set("Content-Type", "application/json")

		client := &http.Client{Timeout: 90 * time.Second}
		res, err := client.Do(req)
		if err != nil {
			lastErr = err
		} else {
			defer res.Body.Close()

			// 对于 502/503/504 等服务器错误，继续重试
			if res.StatusCode >= 500 && res.StatusCode < 600 {
				body, _ := io.ReadAll(res.Body)
				lastErr = fmt.Errorf("component api status %s: %s", res.Status, strings.TrimSpace(string(body)))
				// 服务器错误，等待 2/4/6/.../20 秒后重试
				if attempt < maxRetries {
					waitTime := time.Duration(attempt) * 2 * time.Second
					log.Printf("component page %d got %s, retrying after %v (attempt %d/%d)", pageIndex, res.Status, waitTime, attempt, maxRetries)
					time.Sleep(waitTime)
					continue
				}
				return componentListResponse{}, lastErr
			}

			if res.StatusCode < 200 || res.StatusCode >= 300 {
				body, _ := io.ReadAll(res.Body)
				return componentListResponse{}, fmt.Errorf("component api status %s: %s", res.Status, strings.TrimSpace(string(body)))
			}

			var apiResp componentListResponse
			if err := json.NewDecoder(res.Body).Decode(&apiResp); err != nil {
				lastErr = err
			} else if !apiResp.Success {
				// 检查是否是签名过期错误
				if apiResp.Code == 40007 || strings.Contains(apiResp.Message, "签名已过期") || strings.Contains(apiResp.Message, "签名过期") {
					log.Printf("component page %d got token expired error (code=%d), refreshing token...", pageIndex, apiResp.Code)
					// 强制刷新 token（忽略 1 分钟限制）
					tokenManager.Lock()
					tokenManager.lastRefresh = time.Time{} // 重置时间，强制刷新
					tokenManager.Unlock()
					if err := refreshTokenIfNeeded(cfg); err != nil {
						return componentListResponse{}, fmt.Errorf("failed to refresh token: %w", err)
					}
					// 重试请求（不增加 attempt 计数）
					continue
				}
				return componentListResponse{}, fmt.Errorf("component api error code=%d message=%s", apiResp.Code, apiResp.Message)
			} else {
				return apiResp, nil
			}
		}

		// 网络错误或其他错误，等待 2/4/6/.../20 秒后重试
		if attempt < maxRetries {
			time.Sleep(time.Duration(attempt) * 2 * time.Second)
		}
	}
	return componentListResponse{}, fmt.Errorf("component api request failed after %d retries: %w", maxRetries, lastErr)
}

func loadComponentPage(cfg config, items []componentItem) error {
	rows := make([]componentRow, 0, len(items))
	for _, item := range items {
		rows = append(rows, componentRow{
			ID:                 item.ID,
			CatID:              normalizeNullable(item.CatID),
			Name:               normalizeNullable(item.Name),
			Picture:            normalizeNullable(item.Picture),
			BrandName:          normalizeNullable(item.BrandName),
			BrandID:            normalizeNullable(item.BrandID),
			Supplier:           normalizeNullable(item.Supplier),
			ExtendedAttributes: normalizeNullable(item.ExtendedAttributes),
			Description:        normalizeNullable(item.Description),
			Encapsulation:      normalizeNullable(item.Encapsulation),
			DataSheet:          normalizeNullable(item.DataSheet),
			ECCN:               normalizeNullable(item.ECCN.ToNullableString()),
		})
	}
	return streamLoad(cfg, cfg.Component.StreamLoadURL,
		"id,cat_id,name,picture,brand_name,brand_id,supplier,extended_attributes,description,encapsulation,data_sheet,eccn",
		rows)
}

func buildComponentDDL(db, table string) string {
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
			"DISTRIBUTED BY HASH(`id`) BUCKETS 10\n"+
			"PROPERTIES (\n"+
			"  \"replication_num\" = \"1\"\n"+
			");",
		db, table,
	)
}
