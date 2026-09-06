package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

type encapsulationAPIResponse struct {
	Success bool   `json:"success"`
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		Total       int                `json:"total"`
		Pages       int                `json:"pages"`
		Size        int                `json:"size"`
		CurrentPage int                `json:"currentPage"`
		Rows        []encapsulationItem `json:"rows"`
	} `json:"data"`
}

type encapsulationItem struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	Code         *string  `json:"code"`
	State        *string  `json:"state"`
	RelatedWords []string `json:"relatedWords"`
}

type encapsulationRow struct {
	ID           int64    `json:"id"`
	Name         string   `json:"name"`
	Code         *string  `json:"code"`
	State        int      `json:"state"`
	RelatedWords []string `json:"related_words"`
}

func runEncapsulationImport(cfg config) error {
	firstResp, err := fetchEncapsulationPage(cfg, "", 1)
	if err != nil {
		return err
	}
	if firstResp.Data.Rows == nil && firstResp.Data.Total == 0 {
		return errors.New("no rows returned from encapsulation api")
	}

	total := firstResp.Data.Total
	pages := firstResp.Data.Pages
	if pages <= 0 && total > 0 {
		pageSize := cfg.Encapsulation.PageSize
		if pageSize <= 0 {
			pageSize = 40
		}
		pages = (total + pageSize - 1) / pageSize
	}
	if pages <= 0 {
		pages = 1
	}

	log.Printf("encapsulation api total=%d pages=%d page_size=%d", total, pages, cfg.Encapsulation.PageSize)

	ddl := buildEncapsulationDDL(cfg.StarrocksDB, cfg.Encapsulation.Table)
	log.Println("table ddl:\n" + ddl)
	if cfg.StarrocksDSN != "" {
		if err := ensureTable(cfg, ddl); err != nil {
			return err
		}
	}
	if cfg.Encapsulation.StreamLoadURL == "" {
		return nil
	}

	log.Printf("stream load url: %s", cfg.Encapsulation.StreamLoadURL)
	loaded := 0
	for page := 1; page <= pages; page++ {
		if page > 1 {
			time.Sleep(cfg.RateLimit)
		}
		var resp encapsulationAPIResponse
		if page == 1 {
			resp = firstResp
		} else {
			resp, err = fetchEncapsulationPage(cfg, "", page)
			if err != nil {
				return err
			}
		}
		if len(resp.Data.Rows) == 0 {
			continue
		}
		rows, err := normalizeEncapsulationRows(resp.Data.Rows)
		if err != nil {
			return err
		}
		if err := streamLoad(cfg, cfg.Encapsulation.StreamLoadURL,
			"id,name,code,state,related_words", rows); err != nil {
			return err
		}
		loaded += len(rows)
		log.Printf("encapsulation loaded page %d/%d rows=%d", page, pages, loaded)
	}
	log.Printf("encapsulation import done total rows=%d", loaded)
	return nil
}

func fetchEncapsulationPage(cfg config, name string, pageIndex int) (encapsulationAPIResponse, error) {
	baseURL := strings.TrimRight(cfg.Encapsulation.APIURL, "/")
	params := url.Values{}
	params.Set("name", name)
	params.Set("pageIndex", strconv.Itoa(pageIndex))
	params.Set("pageSize", strconv.Itoa(cfg.Encapsulation.PageSize))
	if cfg.Encapsulation.PageSize <= 0 {
		params.Set("pageSize", "40")
	}
	reqURL := baseURL + "?" + params.Encode()
	req, err := http.NewRequest(http.MethodGet, reqURL, nil)
	if err != nil {
		return encapsulationAPIResponse{}, err
	}
	req.Header.Set("Authorization", cfg.Authorization)

	client := &http.Client{Timeout: 30 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return encapsulationAPIResponse{}, err
	}
	defer res.Body.Close()
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		body, _ := io.ReadAll(res.Body)
		return encapsulationAPIResponse{}, fmt.Errorf("api status %s: %s", res.Status, strings.TrimSpace(string(body)))
	}
	var apiResp encapsulationAPIResponse
	if err := json.NewDecoder(res.Body).Decode(&apiResp); err != nil {
		return encapsulationAPIResponse{}, err
	}
	if !apiResp.Success {
		return encapsulationAPIResponse{}, fmt.Errorf("api error code=%d message=%s", apiResp.Code, apiResp.Message)
	}
	return apiResp, nil
}

func normalizeEncapsulationRows(items []encapsulationItem) ([]encapsulationRow, error) {
	rows := make([]encapsulationRow, 0, len(items))
	for _, it := range items {
		id, err := strconv.ParseInt(strings.TrimSpace(it.ID), 10, 64)
		if err != nil {
			return nil, fmt.Errorf("invalid encapsulation id %q: %w", it.ID, err)
		}
		state := 0
		if it.State != nil {
			state, _ = strconv.Atoi(strings.TrimSpace(*it.State))
		}
		rows = append(rows, encapsulationRow{
			ID:           id,
			Name:         strings.TrimSpace(it.Name),
			Code:         normalizeNullable(it.Code),
			State:        state,
			RelatedWords: it.RelatedWords,
		})
	}
	return rows, nil
}

func buildEncapsulationDDL(db, table string) string {
	return fmt.Sprintf(
		"CREATE TABLE IF NOT EXISTS `%s`.`%s` (\n"+
			"  `id` BIGINT NOT NULL COMMENT '封装ID',\n"+
			"  `name` VARCHAR(128) NULL COMMENT '封装名称',\n"+
			"  `code` VARCHAR(64) NULL COMMENT '封装编码',\n"+
			"  `state` TINYINT NULL COMMENT '状态',\n"+
			"  `related_words` ARRAY<VARCHAR(256)> NULL COMMENT '关联词',\n"+
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
