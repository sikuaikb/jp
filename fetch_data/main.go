package main

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

type config struct {
	Authorization              string // 初始 token，如果为空则自动登录获取
	RateLimit                  time.Duration
	StarrocksDSN               string
	StarrocksDB                string
	StarrocksHost              string
	StarrocksHTTPPort          string
	StarrocksUser              string
	StarrocksPass              string
	LoginUsername              string
	LoginPassword              string
	Brand                      brandConfig
	Component                  componentConfig
	SkuDetail                  skuDetailConfig
	Category                   categoryConfig
	CategoryTemplate           categoryTemplateConfig
	Encapsulation              encapsulationConfig
	ComponentDetailStartID     string
}

type encapsulationConfig struct {
	APIURL        string
	PageSize      int
	Table         string
	StreamLoadURL string
}

type brandConfig struct {
	APIURL        string
	PageIndex     int
	PageSize      int
	Table         string
	StreamLoadURL string
}

type componentConfig struct {
	APIURL           string
	PageIndex        int
	PageSize         int
	Table            string
	StreamLoadURL    string
	WorkerCount      int
	WorkerQPS        int
	BatchSize        int
	RateLimit        time.Duration // component 专属请求间隔，0 表示用全局 RateLimit
	MissingPagesFile string        // 若非空，则从该文件读取待爬取页码并仅爬取这些页
}

type skuDetailConfig struct {
	APIURL        string
	SourceTable   string
	TargetTable   string
	StreamLoadURL string
	DBBatchSize   int
	WorkerCount   int
	WorkerQPS     int
	StatsInterval time.Duration
}

type categoryConfig struct {
	APIURL        string
	Table         string
	StreamLoadURL string
}

type categoryTemplateConfig struct {
	APIURL        string
	Table         string
	StreamLoadURL string
}

// 全局 token 管理器，用于自动刷新过期的 token
var (
	tokenManager struct {
		sync.RWMutex
		currentToken string
		loginUser    string
		loginPass    string
		lastRefresh  time.Time
		failureCount int       // 连续失败次数
		lastFailure  time.Time // 上次失败时间
	}
)

// min 返回两个整数中的较小值
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// tokenRefreshInterval 超过该间隔未刷新则主动刷新 token（仅用于 refreshTokenIfStale）
const tokenRefreshInterval = 8 * time.Hour

// refreshTokenIfNeeded 仅在签名过期错误（如 40007）时调用，执行刷新
func refreshTokenIfNeeded(cfg *config) error {
	tokenManager.Lock()
	defer tokenManager.Unlock()

	if tokenManager.loginUser == "" || tokenManager.loginPass == "" {
		return errors.New("cannot refresh token: missing login credentials")
	}

	if tokenManager.failureCount >= 3 && time.Since(tokenManager.lastFailure) < 5*time.Minute {
		return fmt.Errorf("login failed %d times, please check login endpoint or update token manually", tokenManager.failureCount)
	}

	// 距离上次刷新不到 10 秒则直接返回当前 token，避免频繁刷新
	if time.Since(tokenManager.lastRefresh) < 10*time.Second && tokenManager.currentToken != "" {
		cfg.Authorization = tokenManager.currentToken
		return nil
	}

	log.Printf("Token expired, refreshing...")
	token, err := loginECloud(tokenManager.loginUser, tokenManager.loginPass)
	if err != nil {
		tokenManager.failureCount++
		tokenManager.lastFailure = time.Now()
		return fmt.Errorf("failed to refresh token (failure count: %d): %w", tokenManager.failureCount, err)
	}

	tokenManager.failureCount = 0
	tokenManager.currentToken = token
	tokenManager.lastRefresh = time.Now()
	cfg.Authorization = token
	log.Printf("Token refreshed successfully")
	return nil
}

// refreshTokenIfStale 若距离上次刷新已超过 8 小时则主动刷新，否则不操作（用于请求前检查，避免长跑任务中途过期）
func refreshTokenIfStale(cfg *config) error {
	tokenManager.Lock()
	defer tokenManager.Unlock()

	if tokenManager.currentToken == "" {
		return nil
	}
	if time.Since(tokenManager.lastRefresh) < tokenRefreshInterval {
		cfg.Authorization = tokenManager.currentToken
		return nil
	}
	if tokenManager.loginUser == "" || tokenManager.loginPass == "" {
		return nil
	}
	if tokenManager.failureCount >= 3 && time.Since(tokenManager.lastFailure) < 5*time.Minute {
		return fmt.Errorf("login failed %d times, please check login endpoint or update token manually", tokenManager.failureCount)
	}

	log.Printf("Token not refreshed for %v, refreshing proactively...", tokenRefreshInterval)
	token, err := loginECloud(tokenManager.loginUser, tokenManager.loginPass)
	if err != nil {
		tokenManager.failureCount++
		tokenManager.lastFailure = time.Now()
		return fmt.Errorf("failed to refresh token (failure count: %d): %w", tokenManager.failureCount, err)
	}

	tokenManager.failureCount = 0
	tokenManager.currentToken = token
	tokenManager.lastRefresh = time.Now()
	cfg.Authorization = token
	log.Printf("Token refreshed successfully")
	return nil
}

// isTokenExpiredError 检查是否是签名过期错误
func isTokenExpiredError(err error) bool {
	if err == nil {
		return false
	}
	errStr := err.Error()
	return strings.Contains(errStr, "code=40007") || strings.Contains(errStr, "签名已过期") || strings.Contains(errStr, "签名过期")
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		log.Fatal(err)
	}

	job := flag.String("job", "none", "none|brand|component|component_detail|category|encapsulation")
	componentStartPage := flag.Int("component-start-page", 0, "start page for component import (override config)")
	componentMissingPagesFile := flag.String("component-missing-pages-file", "", "read page numbers from file and crawl only those (e.g. component_missing_pages_from_15000.txt)")
	componentDetailStartID := flag.String("component-detail-start-id", "", "start id (exclusive) for component detail import (for resume; uses key-set pagination by id)")
	forceLogin := flag.Bool("force-login", false, "force re-login to get new authorization token")
	flag.Parse()
	if *componentStartPage > 0 {
		cfg.Component.PageIndex = *componentStartPage
	}
	if *componentMissingPagesFile != "" {
		cfg.Component.MissingPagesFile = *componentMissingPagesFile
	}
	if strings.TrimSpace(*componentDetailStartID) != "" {
		cfg.ComponentDetailStartID = strings.TrimSpace(*componentDetailStartID)
	}
	if *forceLogin {
		// 强制重新登录
		if cfg.LoginUsername != "" && cfg.LoginPassword != "" {
			token, err := loginECloud(cfg.LoginUsername, cfg.LoginPassword)
			if err != nil {
				log.Fatalf("Failed to login: %v", err)
			}
			cfg.Authorization = token
			log.Printf("Successfully logged in and obtained new authorization token")
		} else {
			log.Fatal("Cannot force login: missing login credentials")
		}
	}

	// 初始化全局 token 管理器
	tokenManager.Lock()
	tokenManager.currentToken = cfg.Authorization
	tokenManager.loginUser = cfg.LoginUsername
	tokenManager.loginPass = cfg.LoginPassword
	tokenManager.lastRefresh = time.Now()
	tokenManager.Unlock()

	switch strings.ToLower(strings.TrimSpace(*job)) {
	case "none":
		return
	case "brand":
		if err := runBrandImport(cfg); err != nil {
			log.Fatal(err)
		}
	case "component":
		if err := runComponentImport(&cfg); err != nil {
			log.Fatal(err)
		}
	case "component_detail":
		if err := runComponentDetailImport(cfg); err != nil {
			log.Fatal(err)
		}
	case "category":
		if err := runCategoryImport(cfg); err != nil {
			log.Fatal(err)
		}
	case "encapsulation":
		if err := runEncapsulationImport(cfg); err != nil {
			log.Fatal(err)
		}
	default:
		log.Fatalf("unknown job: %s", *job)
	}
}

func loadConfig() (config, error) {
	// 从环境变量读取所有必需配置
	loginUsername := os.Getenv("ECLOUD_LOGIN_USERNAME")
	loginPassword := os.Getenv("ECLOUD_LOGIN_PASSWORD")
	starrocksUser := os.Getenv("STARROCKS_USER")
	starrocksPass := os.Getenv("STARROCKS_PASSWORD")
	starrocksHost := os.Getenv("STARROCKS_HOST")
	starrocksDB := os.Getenv("STARROCKS_DB")
	starrocksHTTPPort := os.Getenv("STARROCKS_HTTP_PORT")

	// 检查必需的环境变量（只有登录凭据和 StarRocks 密码是必需的）
	var missingVars []string
	if loginUsername == "" {
		missingVars = append(missingVars, "ECLOUD_LOGIN_USERNAME")
	}
	if loginPassword == "" {
		missingVars = append(missingVars, "ECLOUD_LOGIN_PASSWORD")
	}
	if starrocksPass == "" {
		missingVars = append(missingVars, "STARROCKS_PASSWORD")
	}

	if len(missingVars) > 0 {
		return config{}, fmt.Errorf("missing required environment variables: %s", strings.Join(missingVars, ", "))
	}

	// 设置 StarRocks 配置的默认值（如果环境变量未设置）
	if starrocksUser == "" {
		starrocksUser = "root"
	}
	if starrocksHost == "" {
		starrocksHost = "192.168.19.21"
	}
	if starrocksDB == "" {
		starrocksDB = "ods"
	}
	if starrocksHTTPPort == "" {
		starrocksHTTPPort = "8040"
	}

	// 构建 StarRocks DSN
	starrocksDSN := fmt.Sprintf("%s:%s@tcp(%s:9030)/", starrocksUser, starrocksPass, starrocksHost)

	cfg := config{
		LoginUsername: loginUsername,
		LoginPassword: loginPassword,
		RateLimit:     2 * time.Second,
		// Authorization 留空，程序会自动登录获取 token
		Authorization:     "",
		StarrocksDB:       starrocksDB,
		StarrocksHost:     starrocksHost,
		StarrocksHTTPPort: starrocksHTTPPort,
		StarrocksDSN:      starrocksDSN,
		StarrocksUser:     starrocksUser,
		StarrocksPass:     starrocksPass,
		Brand: brandConfig{
			APIURL:        "https://ecloud.jiepei.com/mgrapi/brand/listByPage",
			PageIndex:     1,
			PageSize:      40,
			Table:         "ods_jp_brand",
			StreamLoadURL: "", // 自动构建
		},
		Component: componentConfig{
			APIURL:        "https://ecloud.jiepei.com/mgrapi/component/listByPage",
			PageIndex:     1590,
			PageSize:      100,
			Table:         "ods_jp_component",
			StreamLoadURL: "", // 自动构建
			WorkerCount:   1,                  // 顺序请求，降低 502/504
			WorkerQPS:     1,
			BatchSize:     10000,
			RateLimit:     5 * time.Second,    // component 专属间隔，缓解 API 压力
		},
		SkuDetail: skuDetailConfig{
			APIURL:        "https://ecloud.jiepei.com/mgrapi/component/id",
			SourceTable:   "ods_jp_component",
			TargetTable:   "ods_jp_component_detail",
			StreamLoadURL: "", // 自动构建
			DBBatchSize:   1000,
			WorkerCount:   50,
			WorkerQPS:     5,
			StatsInterval: 2 * time.Second,
		},
		Category: categoryConfig{
			APIURL:        "https://ecloud.jiepei.com/mgrapi/category",
			Table:         "ods_jp_category",
			StreamLoadURL: "", // 自动构建
		},
		CategoryTemplate: categoryTemplateConfig{
			APIURL:        "https://ecloud.jiepei.com/mgrapi/categoryTemplate/list",
			Table:         "ods_jp_category_template",
			StreamLoadURL: "", // 自动构建
		},
		Encapsulation: encapsulationConfig{
			APIURL:        "https://ecloud.jiepei.com/mgrapi/encapsulation/listByPage",
			PageSize:      40,
			Table:         "ods_jp_encapsulation",
			StreamLoadURL: "", // 自动构建
		},
	}

	// 如果 Authorization 为空，自动登录获取 token
	if cfg.Authorization == "" {
		token, err := loginECloud(cfg.LoginUsername, cfg.LoginPassword)
		if err != nil {
			return config{}, fmt.Errorf("failed to auto-login: %w", err)
		}
		cfg.Authorization = token
		log.Printf("Successfully auto-logged in and obtained authorization token")
	}
	if cfg.StarrocksDB == "" {
		cfg.StarrocksDB = "default"
	}
	if cfg.Brand.Table == "" {
		cfg.Brand.Table = "ods_jp_brand"
	}
	if cfg.Brand.StreamLoadURL == "" && cfg.StarrocksHost != "" {
		cfg.Brand.StreamLoadURL = fmt.Sprintf("http://%s:%s/api/%s/%s/_stream_load",
			cfg.StarrocksHost, cfg.StarrocksHTTPPort, cfg.StarrocksDB, cfg.Brand.Table)
	}
	if cfg.Brand.StreamLoadURL != "" &&
		!strings.HasPrefix(cfg.Brand.StreamLoadURL, "http://") &&
		!strings.HasPrefix(cfg.Brand.StreamLoadURL, "https://") {
		cfg.Brand.StreamLoadURL = "http://" + cfg.Brand.StreamLoadURL
	}
	if cfg.Component.Table == "" {
		cfg.Component.Table = "ods_jp_component"
	}
	if cfg.Component.StreamLoadURL == "" && cfg.StarrocksHost != "" {
		cfg.Component.StreamLoadURL = fmt.Sprintf("http://%s:%s/api/%s/%s/_stream_load",
			cfg.StarrocksHost, cfg.StarrocksHTTPPort, cfg.StarrocksDB, cfg.Component.Table)
	}
	if cfg.Component.StreamLoadURL != "" &&
		!strings.HasPrefix(cfg.Component.StreamLoadURL, "http://") &&
		!strings.HasPrefix(cfg.Component.StreamLoadURL, "https://") {
		cfg.Component.StreamLoadURL = "http://" + cfg.Component.StreamLoadURL
	}
	if cfg.SkuDetail.StreamLoadURL == "" && cfg.StarrocksHost != "" && cfg.SkuDetail.TargetTable != "" {
		cfg.SkuDetail.StreamLoadURL = fmt.Sprintf("http://%s:%s/api/%s/%s/_stream_load",
			cfg.StarrocksHost, cfg.StarrocksHTTPPort, cfg.StarrocksDB, cfg.SkuDetail.TargetTable)
	}
	if cfg.SkuDetail.StreamLoadURL != "" &&
		!strings.HasPrefix(cfg.SkuDetail.StreamLoadURL, "http://") &&
		!strings.HasPrefix(cfg.SkuDetail.StreamLoadURL, "https://") {
		cfg.SkuDetail.StreamLoadURL = "http://" + cfg.SkuDetail.StreamLoadURL
	}
	if cfg.Category.Table == "" {
		cfg.Category.Table = "ods_jp_category"
	}
	if cfg.Category.StreamLoadURL == "" && cfg.StarrocksHost != "" {
		cfg.Category.StreamLoadURL = fmt.Sprintf("http://%s:%s/api/%s/%s/_stream_load",
			cfg.StarrocksHost, cfg.StarrocksHTTPPort, cfg.StarrocksDB, cfg.Category.Table)
	}
	if cfg.Category.StreamLoadURL != "" &&
		!strings.HasPrefix(cfg.Category.StreamLoadURL, "http://") &&
		!strings.HasPrefix(cfg.Category.StreamLoadURL, "https://") {
		cfg.Category.StreamLoadURL = "http://" + cfg.Category.StreamLoadURL
	}
	if cfg.CategoryTemplate.Table == "" {
		cfg.CategoryTemplate.Table = "ods_jp_category_template"
	}
	if cfg.CategoryTemplate.StreamLoadURL == "" && cfg.StarrocksHost != "" {
		cfg.CategoryTemplate.StreamLoadURL = fmt.Sprintf("http://%s:%s/api/%s/%s/_stream_load",
			cfg.StarrocksHost, cfg.StarrocksHTTPPort, cfg.StarrocksDB, cfg.CategoryTemplate.Table)
	}
	if cfg.CategoryTemplate.StreamLoadURL != "" &&
		!strings.HasPrefix(cfg.CategoryTemplate.StreamLoadURL, "http://") &&
		!strings.HasPrefix(cfg.CategoryTemplate.StreamLoadURL, "https://") {
		cfg.CategoryTemplate.StreamLoadURL = "http://" + cfg.CategoryTemplate.StreamLoadURL
	}
	if cfg.Encapsulation.Table == "" {
		cfg.Encapsulation.Table = "ods_jp_encapsulation"
	}
	if cfg.Encapsulation.StreamLoadURL == "" && cfg.StarrocksHost != "" {
		cfg.Encapsulation.StreamLoadURL = fmt.Sprintf("http://%s:%s/api/%s/%s/_stream_load",
			cfg.StarrocksHost, cfg.StarrocksHTTPPort, cfg.StarrocksDB, cfg.Encapsulation.Table)
	}
	if cfg.Encapsulation.StreamLoadURL != "" &&
		!strings.HasPrefix(cfg.Encapsulation.StreamLoadURL, "http://") &&
		!strings.HasPrefix(cfg.Encapsulation.StreamLoadURL, "https://") {
		cfg.Encapsulation.StreamLoadURL = "http://" + cfg.Encapsulation.StreamLoadURL
	}

	return cfg, nil
}

func ensureTable(cfg config, ddl string) error {
	db, err := sql.Open("mysql", cfg.StarrocksDSN)
	if err != nil {
		return err
	}
	defer db.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if cfg.StarrocksDB != "" {
		if _, err := db.ExecContext(ctx, fmt.Sprintf("CREATE DATABASE IF NOT EXISTS `%s`", cfg.StarrocksDB)); err != nil {
			return err
		}
	}
	if _, err := db.ExecContext(ctx, ddl); err != nil {
		return err
	}
	return nil
}

func streamLoad(cfg config, streamLoadURL string, columns string, rows any) error {
	body, err := json.Marshal(rows)
	if err != nil {
		return err
	}

	req, err := http.NewRequest(http.MethodPut, streamLoadURL, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.SetBasicAuth(cfg.StarrocksUser, cfg.StarrocksPass)
	req.Header.Set("label", fmt.Sprintf("load_%d", time.Now().UnixNano()))
	req.Header.Set("format", "json")
	req.Header.Set("strip_outer_array", "true")
	req.Header.Set("partial_columns", "true")
	req.Header.Set("columns", columns)
	req.Header.Set("Expect", "100-continue")
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{
		Timeout: 60 * time.Second,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	res, err := client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()

	respBody, _ := io.ReadAll(res.Body)
	if res.StatusCode >= 300 && res.StatusCode < 400 {
		location := res.Header.Get("Location")
		return fmt.Errorf("stream load redirected to %s (status %s): %s", location, res.Status, strings.TrimSpace(string(respBody)))
	}
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return fmt.Errorf("stream load status %s: %s", res.Status, strings.TrimSpace(string(respBody)))
	}
	var loadResp struct {
		Status string `json:"Status"`
	}
	if err := json.Unmarshal(respBody, &loadResp); err == nil {
		if strings.ToUpper(strings.TrimSpace(loadResp.Status)) != "SUCCESS" {
			log.Printf("stream load response: %s", strings.TrimSpace(string(respBody)))
		}
	}
	return nil
}

type loginResponse struct {
	Success bool   `json:"success"`
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		Token string `json:"token"`
	} `json:"data"`
}

func loginECloud(username, password string) (string, error) {
	loginEndpoint := "https://ecloud.jiepei.com/mgrapi/edaManager/login"

	// 使用 POST 请求，参数在 URL query string 中，请求体为空
	// 需要对密码进行 URL 编码
	loginURL := fmt.Sprintf("%s?username=%s&password=%s", loginEndpoint, url.QueryEscape(username), url.QueryEscape(password))

	client := &http.Client{
		Timeout: 30 * time.Second,
		// 自动处理 Cookie
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	// 先访问登录页面获取 Cookie
	preReq, _ := http.NewRequest(http.MethodGet, "https://ecloud.jiepei.com/manager/", nil)
	preReq.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36")
	preResp, err := client.Do(preReq)
	if err == nil && preResp != nil {
		preResp.Body.Close()
	}

	// 创建登录请求，请求体为空
	req, err := http.NewRequest(http.MethodPost, loginURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create login request: %w", err)
	}

	// 添加请求头，模拟浏览器请求
	req.Header.Set("Accept", "application/json, text/plain, */*")
	req.Header.Set("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")
	req.Header.Set("Connection", "keep-alive")
	req.Header.Set("Host", "ecloud.jiepei.com")
	req.Header.Set("Origin", "https://ecloud.jiepei.com")
	req.Header.Set("Referer", "https://ecloud.jiepei.com/manager/")
	req.Header.Set("Sec-Ch-Ua", `"Not(A:Brand";v="8", "Chromium";v="144", "Google Chrome";v="144"`)
	req.Header.Set("Sec-Ch-Ua-Mobile", "?0")
	req.Header.Set("Sec-Ch-Ua-Platform", `"macOS"`)
	req.Header.Set("Sec-Fetch-Dest", "empty")
	req.Header.Set("Sec-Fetch-Mode", "cors")
	req.Header.Set("Sec-Fetch-Site", "same-origin")
	req.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36")

	res, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to execute login request: %w", err)
	}
	defer res.Body.Close()

	respBody, _ := io.ReadAll(res.Body)

	// 首先检查响应头中的 authorization 字段（token 在这里）
	authHeader := res.Header.Get("authorization")
	if authHeader == "" {
		// 尝试大小写不敏感的查找
		for k, v := range res.Header {
			if strings.EqualFold(k, "authorization") && len(v) > 0 {
				authHeader = v[0]
				break
			}
		}
	}
	if authHeader != "" {
		// token 已经在响应头中，直接返回
		if !strings.HasPrefix(authHeader, "EDA_") {
			authHeader = "EDA_" + authHeader
		}
		return authHeader, nil
	}

	// 如果响应头中没有 token，尝试解析响应体
	var loginResp loginResponse
	if err := json.Unmarshal(respBody, &loginResp); err == nil {
		// 如果响应体可以解析，检查是否是成功响应
		if loginResp.Success {
			// 尝试从 data.token 获取
			if loginResp.Data.Token != "" {
				token := loginResp.Data.Token
				if !strings.HasPrefix(token, "EDA_") {
					token = "EDA_" + token
				}
				return token, nil
			}
			// 尝试从响应体直接查找 token
			respStr := string(respBody)
			if strings.Contains(respStr, "token") {
				var dataMap map[string]interface{}
				if err := json.Unmarshal(respBody, &dataMap); err == nil {
					if data, ok := dataMap["data"].(map[string]interface{}); ok {
						if token, ok := data["token"].(string); ok && token != "" {
							if !strings.HasPrefix(token, "EDA_") {
								token = "EDA_" + token
							}
							return token, nil
						}
					}
					// 尝试直接从根级别获取 token
					if token, ok := dataMap["token"].(string); ok && token != "" {
						if !strings.HasPrefix(token, "EDA_") {
							token = "EDA_" + token
						}
						return token, nil
					}
				}
			}
		}
		// 如果 code=20001，说明端点存在但需要其他认证方式
		if loginResp.Code == 20001 {
			return "", fmt.Errorf("login endpoint requires authentication: code=%d message=%s", loginResp.Code, loginResp.Message)
		}
		// 如果 code=20002，说明用户名或密码错误
		if loginResp.Code == 20002 {
			return "", fmt.Errorf("login failed: code=%d message=%s (please check username and password in config)", loginResp.Code, loginResp.Message)
		}
		// 其他错误
		return "", fmt.Errorf("login endpoint %s: code=%d message=%s", loginEndpoint, loginResp.Code, loginResp.Message)
	}

	// 如果无法解析 JSON，检查 HTTP 状态码
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return "", fmt.Errorf("login endpoint returned status %s: %s", res.Status, strings.TrimSpace(string(respBody))[:min(200, len(respBody))])
	}

	// 如果无法解析 JSON，返回原始响应
	return "", fmt.Errorf("login endpoint returned unexpected response: %s", string(respBody)[:min(500, len(respBody))])
}
