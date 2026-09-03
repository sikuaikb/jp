package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
)

// SampleItem 是一条待分类的记录，字段要精简便于 LLM 读取
type SampleItem struct {
	ID           int64  `json:"id"`
	Partno       string `json:"partno"`
	Brand        string `json:"brand"`
	Category     string `json:"category,omitempty"`
	Category2    string `json:"category2,omitempty"`
	SQLL2        string `json:"sql_l2,omitempty"`
	SQLL3        string `json:"sql_l3,omitempty"`
	NoteCN       string `json:"note_cn,omitempty"`
	Note         string `json:"note,omitempty"`
	AllInfo      string `json:"all_info,omitempty"`
	CategoryInfo string `json:"category_info,omitempty"`
	Taginfo      string `json:"taginfo,omitempty"`
}

// L3Sample 声明一个 L3 代码的采样需求：从哪个 dwd_l2 表取，sample size
type L3Sample struct {
	L2Table string
	L2Code  string
	L3Code  string
	Limit   int
}

func defaultSampling(perL3 int) []L3Sample {
	return []L3Sample{
		{"dwd.dwd_l2_voltage_regulator", "voltage_regulator", "ldo_regulator", perL3},
		{"dwd.dwd_l2_voltage_regulator", "voltage_regulator", "dcdc_switching", perL3},
		{"dwd.dwd_l2_bms_supervisor", "bms_supervisor", "battery_charger", perL3},
		{"dwd.dwd_l2_bms_supervisor", "bms_supervisor", "voltage_ref", perL3},
		{"dwd.dwd_l2_bms_supervisor", "bms_supervisor", "supervisor_reset", perL3},
		{"dwd.dwd_l2_driver_ic", "driver_ic", "gate_driver", perL3},
		{"dwd.dwd_l2_driver_ic", "driver_ic", "motor_driver", perL3},
		{"dwd.dwd_l2_driver_ic", "driver_ic", "led_driver", perL3},
	}
}

func sampleFromDB(dsn string, plan []L3Sample) ([]SampleItem, error) {
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, err
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		return nil, err
	}

	var all []SampleItem
	for _, s := range plan {
		q := fmt.Sprintf(`
SELECT t.id,
       COALESCE(p.partno,''),
       COALESCE(p.brandshort,''),
       COALESCE(p.category,''),
       COALESCE(p.category2,''),
       '%s' AS sql_l2,
       t.l3_code,
       COALESCE(p.note_cn,''),
       COALESCE(p.note,''),
       COALESCE(SUBSTR(p.all_info,1,400),''),
       COALESCE(array_join(p.category_info,'|'),''),
       COALESCE(array_join(p.taginfo,'|'),'')
FROM %s t
JOIN dwd.dwd_icpdf_component_param p ON p.id = t.id
WHERE t.l3_code = '%s'
ORDER BY t.id
LIMIT %d`, s.L2Code, s.L2Table, s.L3Code, s.Limit)
		rows, err := db.Query(q)
		if err != nil {
			return nil, fmt.Errorf("sample %s/%s: %w", s.L2Code, s.L3Code, err)
		}
		n := 0
		for rows.Next() {
			var it SampleItem
			if err := rows.Scan(&it.ID, &it.Partno, &it.Brand, &it.Category, &it.Category2,
				&it.SQLL2, &it.SQLL3, &it.NoteCN, &it.Note, &it.AllInfo,
				&it.CategoryInfo, &it.Taginfo); err != nil {
				rows.Close()
				return nil, err
			}
			all = append(all, it)
			n++
		}
		rows.Close()
		log.Printf("sampled %d rows for %s/%s", n, s.L2Code, s.L3Code)
	}
	return all, nil
}

func writeItems(path string, items []SampleItem) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	b, err := json.MarshalIndent(items, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(b, '\n'), 0o644)
}

func readItems(path string) ([]SampleItem, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var items []SampleItem
	if err := json.Unmarshal(b, &items); err != nil {
		return nil, err
	}
	return items, nil
}
