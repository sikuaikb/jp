package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

func main() {
	var (
		mode      = flag.String("mode", "", "sample | classify")
		dsn       = flag.String("dsn", os.Getenv("STARROCKS_DSN"), "StarRocks DSN (sample mode)")
		perL3     = flag.Int("per-l3", 100, "rows per L3 when sampling")
		itemsPath = flag.String("items", "../exports/bench_items.json", "items file path (input for classify, output for sample)")
		baseURL   = flag.String("base", envOr("MODEL_LAKE_BASE_URL", "http://192.168.19.21:11010/model-lake/unified/v1"), "model lake base URL")
		model     = flag.String("model", "", "model id, e.g. google_cloud_gemini/gemini-3-flash-preview")
		batchSize = flag.Int("batch-size", 50, "items per request")
		workers   = flag.Int("workers", 4, "concurrent workers")
		maxTokens = flag.Int("max-tokens", 8000, "chat completion max_tokens")
		timeout   = flag.Duration("timeout", 180*time.Second, "per-request timeout")
		retries   = flag.Int("retries", 2, "retries per batch on failure")
		outPath   = flag.String("out", "", "output JSON path (classify mode, default: auto by model)")
	)
	flag.Parse()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
	go func() { <-sig; cancel() }()

	switch *mode {
	case "sample":
		if *dsn == "" {
			log.Fatal("sample mode needs -dsn or STARROCKS_DSN")
		}
		plan := defaultSampling(*perL3)
		items, err := sampleFromDB(*dsn, plan)
		if err != nil {
			log.Fatalf("sample: %v", err)
		}
		if err := writeItems(*itemsPath, items); err != nil {
			log.Fatalf("write items: %v", err)
		}
		log.Printf("wrote %d items to %s", len(items), *itemsPath)

	case "classify":
		if *model == "" {
			log.Fatal("classify mode needs -model")
		}
		items, err := readItems(*itemsPath)
		if err != nil {
			log.Fatalf("read items: %v", err)
		}
		log.Printf("loaded %d items from %s", len(items), *itemsPath)
		run := RunBench(ctx, *baseURL, *model, items, *batchSize, *workers, *maxTokens, *timeout, *retries)
		effOut := *outPath
		if effOut == "" {
			slug := strings.ReplaceAll(*model, "/", "__")
			effOut = filepath.Join(filepath.Dir(*itemsPath), "bench_"+slug+".json")
		}
		if err := os.MkdirAll(filepath.Dir(effOut), 0o755); err != nil {
			log.Fatalf("mkdir: %v", err)
		}
		b, _ := json.MarshalIndent(run, "", "  ")
		if err := os.WriteFile(effOut, append(b, '\n'), 0o644); err != nil {
			log.Fatalf("write: %v", err)
		}
		log.Printf("model=%s items=%d parsed=%d batches=%d wall=%s tokens=in:%d out:%d total:%d  -> %s",
			*model, len(items), len(run.Results), len(run.Batches), run.WallDuration.Round(time.Millisecond),
			run.TotalUsage.PromptTokens, run.TotalUsage.CompletionTokens, run.TotalUsage.TotalTokens, effOut)

	default:
		log.Fatalf("unknown -mode=%q; use sample|classify", *mode)
	}
}

func envOr(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}
