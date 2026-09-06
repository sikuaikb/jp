# data_etl 使用说明12

## 编译

在 `fetch_data` 目录下执行。需已安装 Go 1.21+。

**编译主程序 jp_fetch_data.sh**（用于 -job component 等）：

```bash
cd fetch_data
go build -o jp_fetch_data.sh .
```

**编译 OpenAPI 爬取程序 jp_openapi_fetch.sh**：

```bash
cd fetch_data
go build -o jp_openapi_fetch.sh ./cmd/openapi_fetch
```

编译完成后，在 `fetch_data` 目录下直接执行 `./jp_fetch_data.sh` 或 `./jp_openapi_fetch.sh` 即可。

## 获取 sku（component）

```bash
./jp_fetch_data.sh -job component -component-missing-pages-file=component_missing_pages_from_15000.txt >> component.log 2>&1 &
```

## 获取 component 详情（component_detail）

从 `ods_jp_component` 按 `id` 顺序逐个调用 `mgrapi/component/id/{id}` 拿详情，写入 `ods_jp_component_detail`（StarRocks 主键模型，重复跑安全 UPSERT）。

**两个关键设计：**

1. **基于 `id` 的 key-set 游标分页**（`WHERE c.id > ? ORDER BY c.id ASC LIMIT N`），严格遍历不漏不重。 
2. **`LEFT JOIN` 自动跳过已写入的 id**：每批只读 `ods_jp_component_detail` 里还不存在的 id，已在目标表的 id 不会再调一次 API。

由此带来的天然行为：
- **断点续跑天然安全**：随时停掉重启，会自动从"未补齐的 id"开始，不需要传任何续跑参数。
- **失败 id 自愈**：某次 API 失败的 id 没写入 detail，下次跑会自动再被选中。
- **可反复执行直到收敛**：源表新增的 id、之前失败的 id，跑一次补一次，一直到 `detail_cnt == source_cnt − API 永久失败数` 为止。

**全量跑 / 增量跑（同一条命令）：**

```bash
./jp_fetch_data_linux -job component_detail >> component_detail.log 2>&1 &
```

**指定起点（可选，主要用于调试或跳过某段）：**

```bash
./jp_fetch_data_linux -job component_detail \
  -component-detail-start-id "某个 id" \
  >> component_detail.log 2>&1 &
```

> 注意：传 `-component-detail-start-id` 后，**id ≤ 该值范围内**未写入的 id 这一轮会被跳过；下次不传该参数再跑一遍即可补齐。

日志里会周期性输出：

```
component_detail processed=12345, window=678, qps=339.00
processed 10000 rows, last_id="xxxxxxxxxxxxxxxxx"
component_detail insert_rows=987
```

**核对进度：**

```sql
SELECT
  (SELECT COUNT(*) FROM ods.ods_jp_component WHERE id IS NOT NULL AND id != '') AS source_cnt,
  (SELECT COUNT(*) FROM ods.ods_jp_component_detail) AS detail_cnt;
```

## OpenAPI 爬取任务（jp_openapi_fetch.sh）

`jp_openapi_fetch.sh` 是由 `cmd/openapi_fetch/main.go` 编译的**二进制**，用于数据云 OpenApi 爬取。

### 环境变量（必填）

```bash
export OPENAPI_ACCESS_KEY_ID="你的AccessKeyId"
export OPENAPI_ACCESS_KEY_SECRET="你的AccessKeySecret"
# listByPageAllFromTable 从表拉取时，若不传 -dsn，则需：
export STARROCKS_DSN="user:pass@tcp(host:port)/db"
```

### 爬取 detail 表（从 ods 表分页拉全量）

从 `ods_jp_component_sku` 按 offset 分页读取，调用 listByPageAll 拉详情并写入 `ods_jp_component_sku_detail`。

**从第 60001 条开始跑（断点续跑）：**

```bash
./jp_openapi_fetch.sh -cmd listByPageAllFromTable \
  -detail-table ods_jp_component_sku_detail \
  -offset 60000 \
  >> component_sku_detail.log 2>&1 &
```

**从头全表跑：**

```bash
./jp_openapi_fetch.sh -cmd listByPageAllFromTable \
  -detail-table ods_jp_component_sku_detail \
  >> component_sku_detail.log 2>&1 &
```

### 常用参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-cmd` | (必填) | `listByPageAllFromTable`：从表分页拉取并写 detail |
| `-detail-table` | - | 写入的表名，如 `ods_jp_component_sku_detail`；全表跑时必填 |
| `-offset` | 0 | 从第几条开始（0 表示从头） |
| `-limit` | 0 | 最多读多少行，0=全表分页 |
| `-table` | ods_jp_component_sku | 源表名 |
| `-db` | ods | 数据库名 |
| `-page-size` | 5000 | 每页行数 |
| `-workers` | 10 | 并发请求数 |
| `-dsn` | 取环境变量 STARROCKS_DSN | StarRocks 连接串 |

### 后台跑并记日志（推荐）

```bash
nohup ./jp_openapi_fetch.sh -cmd listByPageAllFromTable \
  -detail-table ods_jp_component_sku_detail \
  -offset 60000 \
  >> component_sku_detail.log 2>&1 &
echo $!   # 记下 PID
```

查看进度：`tail -f component_sku_detail.log`

### 其他 -cmd 用法

- **findSku**：查单个物料（需 `-model -brand -encapsulation`）
- **materialCodeList**：物料编码变更记录（需 `-startTime -endTime`）
- **listByPageAll**：按 JSON 或 stdin 批量查（需 `-input <文件或->` 或 `-model`）
