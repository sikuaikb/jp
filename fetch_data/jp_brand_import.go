package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"strconv"
	"strings"
	"time"
)

type apiResponse struct {
	Success bool   `json:"success"`
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		Total       int     `json:"total"`
		Pages       int     `json:"pages"`
		Size        int     `json:"size"`
		CurrentPage int     `json:"currentPage"`
		Rows        []brand `json:"rows"`
	} `json:"data"`
}

type brand struct {
	ID              string   `json:"id"`
	Name            string   `json:"name"`
	Abbr            string   `json:"abbr"`
	Logo            *string  `json:"logo"`
	State           string   `json:"state"`
	OfficialWebsite *string  `json:"officialWebsite"`
	RelatedWords    []string `json:"relatedWords"`
	Level           int      `json:"level"`
	Type            int      `json:"type"`
}

type brandRow struct {
	ID              int64    `json:"id"`
	Name            string   `json:"name"`
	Abbr            string   `json:"abbr"`
	Logo            *string  `json:"logo"`
	State           int      `json:"state"`
	OfficialWebsite *string  `json:"official_website"`
	RelatedWords    []string `json:"related_words"`
	Level           int      `json:"level"`
	Type            int      `json:"type"`
}

func runBrandImport(cfg config) error {
	firstResp, err := fetchBrands(cfg, cfg.Brand.PageIndex)
	if err != nil {
		return err
	}
	if len(firstResp.Data.Rows) == 0 {
		return errors.New("no rows returned from api")
	}

	log.Printf("api total=%d pages=%d page_size=%d", firstResp.Data.Total, firstResp.Data.Pages, firstResp.Data.Size)

	ddl := buildBrandDDL(cfg.StarrocksDB, cfg.Brand.Table)
	log.Println("table ddl:\n" + ddl)

	if cfg.StarrocksDSN != "" {
		if err := ensureTable(cfg, ddl); err != nil {
			return err
		}
	}

	if cfg.Brand.StreamLoadURL == "" {
		return nil
	}

	log.Printf("stream load url: %s", cfg.Brand.StreamLoadURL)
	if err := loadBrandPage(cfg, firstResp.Data.Rows); err != nil {
		return err
	}

	for page := cfg.Brand.PageIndex + 1; page <= firstResp.Data.Pages; page++ {
		time.Sleep(cfg.RateLimit)
		resp, err := fetchBrands(cfg, page)
		if err != nil {
			return err
		}
		if err := loadBrandPage(cfg, resp.Data.Rows); err != nil {
			return err
		}
		log.Printf("loaded page %d/%d", page, firstResp.Data.Pages)
	}
	return nil
}

func fetchBrands(cfg config, pageIndex int) (apiResponse, error) {
	payload := &bytes.Buffer{}
	writer := multipart.NewWriter(payload)
	if err := writer.WriteField("pageIndex", strconv.Itoa(pageIndex)); err != nil {
		return apiResponse{}, err
	}
	if err := writer.WriteField("pageSize", strconv.Itoa(cfg.Brand.PageSize)); err != nil {
		return apiResponse{}, err
	}
	if err := writer.Close(); err != nil {
		return apiResponse{}, err
	}

	req, err := http.NewRequest(http.MethodPost, cfg.Brand.APIURL, payload)
	if err != nil {
		return apiResponse{}, err
	}
	req.Header.Set("Authorization", cfg.Authorization)
	req.Header.Set("Content-Type", writer.FormDataContentType())

	client := &http.Client{Timeout: 30 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return apiResponse{}, err
	}
	defer res.Body.Close()

	if res.StatusCode < 200 || res.StatusCode >= 300 {
		body, _ := io.ReadAll(res.Body)
		return apiResponse{}, fmt.Errorf("api status %s: %s", res.Status, strings.TrimSpace(string(body)))
	}

	var apiResp apiResponse
	if err := json.NewDecoder(res.Body).Decode(&apiResp); err != nil {
		return apiResponse{}, err
	}
	if !apiResp.Success {
		return apiResponse{}, fmt.Errorf("api error code=%d message=%s", apiResp.Code, apiResp.Message)
	}
	return apiResp, nil
}

func loadBrandPage(cfg config, brands []brand) error {
	rows, err := normalizeBrandRows(brands)
	if err != nil {
		return err
	}
	return streamLoad(cfg, cfg.Brand.StreamLoadURL, "id,name,abbr,logo,state,official_website,related_words,level,type", rows)
}

func normalizeBrandRows(brands []brand) ([]brandRow, error) {
	rows := make([]brandRow, 0, len(brands))
	for _, b := range brands {
		id, err := strconv.ParseInt(b.ID, 10, 64)
		if err != nil {
			return nil, fmt.Errorf("invalid id %q: %w", b.ID, err)
		}
		state, err := strconv.Atoi(strings.TrimSpace(b.State))
		if err != nil {
			return nil, fmt.Errorf("invalid state %q: %w", b.State, err)
		}

		rows = append(rows, brandRow{
			ID:              id,
			Name:            strings.TrimSpace(b.Name),
			Abbr:            strings.TrimSpace(b.Abbr),
			Logo:            normalizeNullable(b.Logo),
			State:           state,
			OfficialWebsite: normalizeNullable(b.OfficialWebsite),
			RelatedWords:    b.RelatedWords,
			Level:           b.Level,
			Type:            b.Type,
		})
	}
	return rows, nil
}

func normalizeNullable(value *string) *string {
	if value == nil {
		return nil
	}
	trimmed := strings.TrimSpace(*value)
	if trimmed == "" || strings.EqualFold(trimmed, "null") {
		return nil
	}
	return &trimmed
}

func buildBrandDDL(db, table string) string {
	return fmt.Sprintf(
		"CREATE TABLE IF NOT EXISTS `%s`.`%s` (\n"+
			"  `id` BIGINT NOT NULL COMMENT '品牌ID',\n"+
			"  `name` VARCHAR(128) NULL COMMENT '品牌名称',\n"+
			"  `abbr` VARCHAR(64) NULL COMMENT '品牌简称',\n"+
			"  `logo` VARCHAR(256) NULL COMMENT '品牌logo',\n"+
			"  `state` TINYINT NULL COMMENT '状态',\n"+
			"  `official_website` VARCHAR(512) NULL COMMENT '官网',\n"+
			"  `related_words` ARRAY<VARCHAR(256)> NULL COMMENT '关联词',\n"+
			"  `level` INT NULL COMMENT '层级',\n"+
			"  `type` TINYINT NULL COMMENT '类型',\n"+
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
