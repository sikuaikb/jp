package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"
)

type categoryAPIResponse struct {
	Success bool         `json:"success"`
	Code    int          `json:"code"`
	Message string       `json:"message"`
	Data    categoryNode `json:"data"`
}

type categoryTemplateResponse struct {
	Success bool                   `json:"success"`
	Code    int                    `json:"code"`
	Message string                 `json:"message"`
	Data    []categoryTemplateItem `json:"data"`
}

type categoryNode struct {
	ID          string         `json:"id"`
	PID         string         `json:"pid"`
	Title       string         `json:"title"`
	TitleEn     *string        `json:"titleEn"`
	IconURL     *string        `json:"iconUrl"`
	Code        *string        `json:"code"`
	ReplaceEval *string        `json:"replaceEval"`
	Pin2PinEval *string        `json:"pin2PinEval"`
	Leaf        bool           `json:"leaf"`
	Hide        int            `json:"hide"`
	State       string         `json:"state"`
	Children    []categoryNode `json:"children"`
}

type categoryRow struct {
	ID          int64   `json:"id"`
	PID         int64   `json:"pid"`
	Title       string  `json:"title"`
	TitleEn     *string `json:"title_en"`
	IconURL     *string `json:"icon_url"`
	Code        *string `json:"code"`
	ReplaceEval *string `json:"replace_eval"`
	Pin2PinEval *string `json:"pin2pin_eval"`
	Leaf        int     `json:"leaf"`
	Hide        int     `json:"hide"`
	State       int     `json:"state"`
}

type categoryTemplateItem struct {
	ExpressionOfReplaceable *string `json:"expressionOfReplaceable"`
	ValueType               *string `json:"valueType"`
	WhetherMust             *string `json:"whetherMust"`
	Name                    string  `json:"name"`
	Weight                  float64 `json:"weight"`
	NameEn                  *string `json:"nameEn"`
	TransitionFunction      *string `json:"transitionFunction"`
	ExpressionOfPinToPin    *string `json:"expressionOfPinToPin"`
}

type categoryTemplateRow struct {
	CategoryID              int64   `json:"category_id"`
	ExpressionOfReplaceable *string `json:"expression_of_replaceable"`
	ValueType               int     `json:"value_type"`
	WhetherMust             int     `json:"whether_must"`
	Name                    string  `json:"name"`
	Weight                  float64 `json:"weight"`
	NameEn                  *string `json:"name_en"`
	TransitionFunction      *string `json:"transition_function"`
	ExpressionOfPinToPin    *string `json:"expression_of_pin2pin"`
}

func runCategoryImport(cfg config) error {
	resp, err := fetchCategoryTree(cfg)
	if err != nil {
		return err
	}
	rows, err := flattenCategoryTree(resp.Data)
	if err != nil {
		return err
	}
	if len(rows) == 0 {
		return fmt.Errorf("no rows returned from category api")
	}

	ddl := buildCategoryDDL(cfg.StarrocksDB, cfg.Category.Table)
	log.Println("table ddl:\n" + ddl)
	if cfg.StarrocksDSN != "" {
		if err := ensureTable(cfg, ddl); err != nil {
			return err
		}
	}
	if cfg.Category.StreamLoadURL == "" {
		return nil
	}
	log.Printf("stream load url: %s", cfg.Category.StreamLoadURL)
	if err := streamLoad(cfg, cfg.Category.StreamLoadURL,
		"id,pid,title,title_en,icon_url,code,replace_eval,pin2pin_eval,leaf,hide,state", rows); err != nil {
		return err
	}
	log.Printf("category loaded rows=%d", len(rows))

	if err := loadCategoryTemplates(cfg, rows); err != nil {
		return err
	}
	return nil
}

func fetchCategoryTree(cfg config) (categoryAPIResponse, error) {
	reqBody := bytes.NewBufferString("{}")
	req, err := http.NewRequest(http.MethodPost, cfg.Category.APIURL, reqBody)
	if err != nil {
		return categoryAPIResponse{}, err
	}
	req.Header.Set("Authorization", cfg.Authorization)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 30 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return categoryAPIResponse{}, err
	}
	defer res.Body.Close()
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		body, _ := io.ReadAll(res.Body)
		return categoryAPIResponse{}, fmt.Errorf("api status %s: %s", res.Status, strings.TrimSpace(string(body)))
	}
	var apiResp categoryAPIResponse
	if err := json.NewDecoder(res.Body).Decode(&apiResp); err != nil {
		return categoryAPIResponse{}, err
	}
	if !apiResp.Success {
		return categoryAPIResponse{}, fmt.Errorf("api error code=%d message=%s", apiResp.Code, apiResp.Message)
	}
	return apiResp, nil
}

func flattenCategoryTree(root categoryNode) ([]categoryRow, error) {
	rows := make([]categoryRow, 0, 1024)
	if err := appendCategoryNode(&rows, root); err != nil {
		return nil, err
	}
	return rows, nil
}

func appendCategoryNode(rows *[]categoryRow, node categoryNode) error {
	id, err := strconv.ParseInt(strings.TrimSpace(node.ID), 10, 64)
	if err != nil {
		return fmt.Errorf("invalid category id %q: %w", node.ID, err)
	}
	pid, err := strconv.ParseInt(strings.TrimSpace(node.PID), 10, 64)
	if err != nil {
		return fmt.Errorf("invalid category pid %q: %w", node.PID, err)
	}
	state := 0
	if strings.TrimSpace(node.State) != "" {
		if parsed, err := strconv.Atoi(strings.TrimSpace(node.State)); err == nil {
			state = parsed
		}
	}

	*rows = append(*rows, categoryRow{
		ID:          id,
		PID:         pid,
		Title:       strings.TrimSpace(node.Title),
		TitleEn:     normalizeNullable(node.TitleEn),
		IconURL:     normalizeNullable(node.IconURL),
		Code:        normalizeNullable(node.Code),
		ReplaceEval: normalizeNullable(node.ReplaceEval),
		Pin2PinEval: normalizeNullable(node.Pin2PinEval),
		Leaf:        boolToInt(node.Leaf),
		Hide:        node.Hide,
		State:       state,
	})
	for _, child := range node.Children {
		if err := appendCategoryNode(rows, child); err != nil {
			return err
		}
	}
	return nil
}

func boolToInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func loadCategoryTemplates(cfg config, categories []categoryRow) error {
	if cfg.CategoryTemplate.StreamLoadURL == "" {
		return nil
	}
	ddl := buildCategoryTemplateDDL(cfg.StarrocksDB, cfg.CategoryTemplate.Table)
	log.Println("template table ddl:\n" + ddl)
	if cfg.StarrocksDSN != "" {
		if err := ensureTable(cfg, ddl); err != nil {
			return err
		}
	}
	log.Printf("template stream load url: %s", cfg.CategoryTemplate.StreamLoadURL)

	const batchSize = 1000
	batch := make([]categoryTemplateRow, 0, batchSize)
	loaded := 0
	rateLimit := cfg.RateLimit
	if rateLimit > 200*time.Millisecond {
		rateLimit = 200 * time.Millisecond
	}
	leafProcessed := 0
	leafTotal := 0
	for _, row := range categories {
		if row.Leaf == 1 && row.ID > 0 {
			leafTotal++
		}
	}
	log.Printf("category template fetch start leaf_total=%d rate_limit=%s", leafTotal, rateLimit)
	lastLog := time.Now()
	for _, row := range categories {
		if row.Leaf != 1 || row.ID <= 0 {
			continue
		}
		leafProcessed++
		if rateLimit > 0 {
			time.Sleep(rateLimit)
		}
		items, err := fetchCategoryTemplate(cfg, row.ID)
		if err != nil {
			return err
		}
		for _, item := range items {
			batch = append(batch, normalizeCategoryTemplateRow(row.ID, item))
			if len(batch) >= batchSize {
				if err := streamLoad(cfg, cfg.CategoryTemplate.StreamLoadURL,
					"category_id,expression_of_replaceable,value_type,whether_must,name,weight,name_en,transition_function,expression_of_pin2pin", batch); err != nil {
					return err
				}
				loaded += len(batch)
				batch = batch[:0]
			}
		}
		if leafProcessed%50 == 0 || time.Since(lastLog) >= 30*time.Second {
			log.Printf("category templates fetched leaf=%d/%d rows=%d", leafProcessed, leafTotal, loaded+len(batch))
			lastLog = time.Now()
		}
	}
	if len(batch) > 0 {
		if err := streamLoad(cfg, cfg.CategoryTemplate.StreamLoadURL,
			"category_id,expression_of_replaceable,value_type,whether_must,name,weight,name_en,transition_function,expression_of_pin2pin", batch); err != nil {
			return err
		}
		loaded += len(batch)
	}
	log.Printf("category template fetch done leaf=%d/%d rows=%d", leafProcessed, leafTotal, loaded)
	return nil
}

func fetchCategoryTemplate(cfg config, categoryID int64) ([]categoryTemplateItem, error) {
	url := fmt.Sprintf("%s/%d", strings.TrimRight(cfg.CategoryTemplate.APIURL, "/"), categoryID)
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", cfg.Authorization)

	client := &http.Client{Timeout: 30 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		body, _ := io.ReadAll(res.Body)
		return nil, fmt.Errorf("category template api status %s: %s", res.Status, strings.TrimSpace(string(body)))
	}
	var apiResp categoryTemplateResponse
	if err := json.NewDecoder(res.Body).Decode(&apiResp); err != nil {
		return nil, err
	}
	if !apiResp.Success {
		return nil, fmt.Errorf("category template api error code=%d message=%s", apiResp.Code, apiResp.Message)
	}
	return apiResp.Data, nil
}

func normalizeCategoryTemplateRow(categoryID int64, item categoryTemplateItem) categoryTemplateRow {
	return categoryTemplateRow{
		CategoryID:              categoryID,
		ExpressionOfReplaceable: normalizeNullable(item.ExpressionOfReplaceable),
		ValueType:               parseNullableInt(item.ValueType),
		WhetherMust:             parseNullableInt(item.WhetherMust),
		Name:                    strings.TrimSpace(item.Name),
		Weight:                  item.Weight,
		NameEn:                  normalizeNullable(item.NameEn),
		TransitionFunction:      normalizeNullable(item.TransitionFunction),
		ExpressionOfPinToPin:    normalizeNullable(item.ExpressionOfPinToPin),
	}
}

func parseNullableInt(value *string) int {
	if value == nil {
		return 0
	}
	trimmed := strings.TrimSpace(*value)
	if trimmed == "" || strings.EqualFold(trimmed, "null") {
		return 0
	}
	parsed, err := strconv.Atoi(trimmed)
	if err != nil {
		return 0
	}
	return parsed
}

func buildCategoryDDL(db, table string) string {
	return fmt.Sprintf(
		"CREATE TABLE IF NOT EXISTS `%s`.`%s` (\n"+
			"  `id` BIGINT NOT NULL COMMENT '分类ID',\n"+
			"  `pid` BIGINT NOT NULL COMMENT '父级分类ID',\n"+
			"  `title` VARCHAR(256) NULL COMMENT '分类名称',\n"+
			"  `title_en` VARCHAR(256) NULL COMMENT '分类英文名',\n"+
			"  `icon_url` VARCHAR(512) NULL COMMENT '图标URL',\n"+
			"  `code` VARCHAR(64) NULL COMMENT '分类编码',\n"+
			"  `replace_eval` VARCHAR(64) NULL COMMENT '替代评估',\n"+
			"  `pin2pin_eval` VARCHAR(64) NULL COMMENT 'Pin2Pin评估',\n"+
			"  `leaf` TINYINT NULL COMMENT '是否叶子节点',\n"+
			"  `hide` TINYINT NULL COMMENT '是否隐藏',\n"+
			"  `state` TINYINT NULL COMMENT '状态',\n"+
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

func buildCategoryTemplateDDL(db, table string) string {
	return fmt.Sprintf(
		"CREATE TABLE IF NOT EXISTS `%s`.`%s` (\n"+
			"  `category_id` BIGINT NOT NULL COMMENT '分类ID',\n"+
			"  `name` VARCHAR(256) NOT NULL COMMENT '字段名称',\n"+
			"  `expression_of_replaceable` VARCHAR(32) NULL COMMENT '替代评估表达式',\n"+
			"  `value_type` TINYINT NULL COMMENT '值类型',\n"+
			"  `whether_must` TINYINT NULL COMMENT '是否必填',\n"+
			"  `weight` DOUBLE NULL COMMENT '权重',\n"+
			"  `name_en` VARCHAR(256) NULL COMMENT '字段英文名称',\n"+
			"  `transition_function` STRING NULL COMMENT '转换函数',\n"+
			"  `expression_of_pin2pin` VARCHAR(32) NULL COMMENT 'Pin2Pin评估表达式',\n"+
			"  `create_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '记录入库时间',\n"+
			"  `update_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '记录更新时间（数据更新时手动刷新）'\n"+
			") ENGINE=OLAP\n"+
			"PRIMARY KEY(`category_id`, `name`)\n"+
			"DISTRIBUTED BY HASH(`category_id`) BUCKETS 1\n"+
			"PROPERTIES (\n"+
			"  \"replication_num\" = \"1\"\n"+
			");",
		db, table,
	)
}
