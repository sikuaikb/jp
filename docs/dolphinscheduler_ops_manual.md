# 海豚调度（DolphinScheduler）ETL 操作手册

本文档说明：**如何把本仓库任意 ETL 脚本发布到 DS Worker**，以及**在海豚调度里配置工作流的通用方法**。  
具体业务链路（分类、属性标准化、PDF 直通等）仅作为**示例**附在文末，配置工作流时请按通用模板替换「入口命令」即可。

---

## 1. 架构总览

```text
开发者 push main
       │
       ▼
GitLab CI (shell runner)
  ├─ deploy_component_etl ──► NFS PVC /opt/data_etl/releases/<sha>
  │                              └─ current → 最新 release 软链
  └─ build_ds_worker_image ──► GitLab Registry ds-worker:stable-etl
                               └─ rollout dolphinscheduler-worker StatefulSet

K8s 集群 (namespace: dolphinscheduler)
  dolphinscheduler-worker-0
    ├─ 挂载 /opt/data_etl          ← 本仓库代码 (PVC)
    ├─ 挂载 /opt/data_etl_secret   ← db.env (K8s Secret)
    └─ 镜像 ds-worker              ← python3 + requirements.txt 中的依赖

海豚调度 UI
  Shell 任务 → 标准 bootstrap → 你的入口脚本/SQL → StarRocks
```

| 组件 | 路径 / 名称 | 说明 |
|------|-------------|------|
| ETL 代码 | `/opt/data_etl/current` | CI 每次 push 更新；`current` 软链指向 `releases/<commit_sha>` |
| 历史版本 | `/opt/data_etl/releases/<sha>/` | 工作流参数可 pin 到指定 commit |
| 数据库凭据 | `/opt/data_etl_secret/db.env` | CI 从 GitLab 变量 `MYSQL_*` 写入 Secret，**不进 Git** |
| Worker 镜像 | `…/ds-worker:stable-etl` | 基础 DS Worker + `docker/ds-worker/requirements.txt` |
| 凭据加载 | `sql_scripts/load_env.sh` | Worker 上统一入口，读 Secret 导出 `MYSQL_*` |

**与业务解耦的原则：**

- CI **只负责**把整仓代码和 DB 凭据送到 Worker；**不负责**绑定某一具体工作流。
- 每个海豚工作流自行选择：跑哪个脚本、prod/test、是否 pin 代码版本、单节点还是多节点 DAG。

---

## 2. 前置条件

### 2.1 集群与海豚调度

- K3s / K8s 集群，命名空间 `dolphinscheduler`（可改，见 CI 变量 `K8S_NAMESPACE`）
- Helm 已部署 DolphinScheduler，Worker StatefulSet 正常运行
- 海豚调度 UI 可访问，已创建项目 / 租户
- Shell 任务默认在 **Worker** 节点执行（不要指定 Master）

### 2.2 GitLab CI 变量

详见 [`ci/README.md`](../ci/README.md)。摘要：

| 变量 | 必填 | 说明 |
|------|------|------|
| `KUBECONFIG` | deploy / rollout 需要 | Type=**File**，内网可达的 kubeconfig |
| `MYSQL_*` | deploy 需要 | 写入 Worker Secret |
| `BUILD_DS_WORKER_IMAGE` | 否 | `=1` 手动触发镜像 build |

### 2.3 本地开发凭据

```bash
cp sql_scripts/local.env.example sql_scripts/local.env
source sql_scripts/local.env
```

Worker **不读** `local.env`，只读 `/opt/data_etl_secret/db.env`。

---

## 3. CI 流水线（与具体工作流无关）

| Job | 触发 | 作用 |
|-----|------|------|
| `deploy_component_etl` | main 每次 push | 发布代码到 PVC，更新 Secret，验证 Worker 挂载 |
| `build_ds_worker_image` | `requirements.txt` / `Dockerfile` 变更，或 `BUILD_DS_WORKER_IMAGE=1` | 构建 Worker 扩展镜像并 rollout |

手动执行：

```bash
bash ci/deploy_to_ds_worker.sh      # 需 KUBECONFIG + MYSQL_*
bash ci/build_ds_worker_image.sh    # 需 docker + CI Registry 或本地配置
```

Worker 镜像与 Python 依赖说明见 [`docker/ds-worker/README.md`](../docker/ds-worker/README.md)。

---

## 4. 通用环境变量约定

海豚 Shell 任务通过 **bootstrap**（见下节）加载环境后，本仓库脚本通常识别：

| 变量 | 来源 | 说明 |
|------|------|------|
| `MYSQL_HOST` / `PORT` / `USER` / `PASSWORD` | `load_env.sh` ← Secret | 连接 StarRocks FE |
| `STARROCKS_*` | 同上（别名） | 部分脚本使用 |
| `DWD_SCHEMA` | 工作流 bootstrap 按 `env` 设置 | 默认 `dwd`；测试用 `test_dwd` |
| `DIM_SCHEMA` | 同上 | 默认 `dim`；测试用 `test_dim` |
| `ALLOW_PROD=1` | bootstrap（prod 时可选） | 部分 `run_*.sh` 写 prod 库前的保护门 |
| `REPO_ROOT` | bootstrap 或脚本推断 | 仓库根，少数 Python 入口使用 |
| `ETL_SECRET_ENV_FILE` | bootstrap 固定 | 默认 `/opt/data_etl_secret/db.env` |

业务脚本若还有自有变量（如 `ONLY_STEPS`、`SKIP_UPSERT`），在工作流最后一行入口命令前 `export` 即可，或在 DS「环境管理」中配置。

---

## 5. 工作流配置（通用，核心）

本节适用于**任意**本仓库 ETL 任务：分类、属性标准化、foundation 回填、PDF 链路、test 目录下的 sandbox 脚本等。

### 5.1 Shell 节点基本约定

| 约定 | 说明 |
|------|------|
| 执行位置 | **Worker**（默认 worker group） |
| 脚本开头 | `set -euo pipefail` — 任一步失败立即退出 |
| 退出码 | 入口脚本返回非 0 → DS 标红，可配重试 |
| 日志 | 业务脚本应打印关键步骤；在 DS「工作流实例 → 任务日志」查看 |
| 幂等 | 优先选用仓库内已声明幂等的 `run_*.py` / `build_*.sql`；多节点 DAG 时注意下游依赖 |

### 5.2 推荐工作流参数（全仓通用）

在海豚调度 **工作流定义 → 全局参数**（或启动参数）中声明，便于 prod/test 切换、代码 pin 版本：

| 参数名 | 示例值 | 说明 |
|--------|--------|------|
| `etl_repo_base` | `/opt/data_etl` | 代码挂载根目录（与 CI `ETL_BASE` 一致） |
| `code_version` | `current` | `current` = 最新 deploy；或完整 commit sha |
| `env` | `prod` | `prod` 或 `test`，控制 schema |
| `etl_cmd` | （见 5.4） | **你要执行的业务入口**；不同工作流填不同值 |

> `etl_cmd` 是区分不同工作流的唯一必要差异；bootstrap 部分所有工作流相同。

### 5.3 标准 bootstrap 模板（复制到每个 Shell 节点）

**所有工作流的前半段应一致**，只在最后一行执行 `${etl_cmd}`：

```bash
set -euo pipefail

# --- 1. 定位代码目录 ---
if [ "${code_version}" = "current" ]; then
  export repo_root="${etl_repo_base}/current"
else
  export repo_root="${etl_repo_base}/releases/${code_version}"
fi
cd "${repo_root}"
export REPO_ROOT="${repo_root}"

# --- 2. 加载数据库凭据 ---
export ETL_SECRET_ENV_FILE=/opt/data_etl_secret/db.env
source sql_scripts/load_env.sh

# --- 3. prod / test schema ---
case "${env}" in
  test)
    export DWD_SCHEMA=test_dwd
    export DIM_SCHEMA=test_dim
    ;;
  prod)
    export DWD_SCHEMA=dwd
    export DIM_SCHEMA=dim
    export ALLOW_PROD=1
    ;;
  *)
    echo "未知 env=${env}，仅支持 prod / test" >&2
    exit 2
    ;;
esac

echo "[bootstrap] repo=${repo_root} env=${env} dwd=${DWD_SCHEMA} dim=${DIM_SCHEMA}"

# --- 4. 业务入口（由各工作流的 etl_cmd 参数决定）---
eval "${etl_cmd}"
```

**DS UI 配置步骤：**

1. 项目管理 → 工作流定义 → **创建工作流**
2. 拖入 **Shell** 任务，Worker 组选默认 Worker
3. 「自定义参数」或工作流级参数：填入上表四个参数；`etl_cmd` 按 5.4 选择
4. Shell 脚本框：粘贴上方 bootstrap（可存为 DS 资源中心模板复用）
5. 保存 → **试运行** → 看日志是否有 bootstrap 行且无报错
6. 配置定时 / 依赖 / 失败告警

### 5.4 三种常见入口形式（替换 `etl_cmd`）

本仓库 ETL 入口形态不一，工作流只需改 `etl_cmd`（或 bootstrap 最后一行）：

| 类型 | 何时使用 | `etl_cmd` 示例 |
|------|----------|----------------|
| **Python 编排** | 多步 SQL、需 fail-fast、不依赖 mysql CLI | `python3 sql_scripts/pdf_pipe/run_pdf_pipe_ds.py` |
| **Bash 一键** | 目录内已有 `run_*.sh`，加载 env 后跑 mysql | `bash sql_scripts/1.classify/run_classify.sh prod` |
| **单条 SQL** | 单次 DDL/DML | `mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --default-character-set=utf8mb4 < sql_scripts/foundation/xxx.sql` |

说明：

- **Python / 自包含脚本**：通常已读 `MYSQL_*`，bootstrap 的 schema 变量对其生效（若脚本支持 `DWD_SCHEMA`）。
- **`run_*.sh`**：多数会再次 `source local.env` 或读 `MYSQL_*`；Worker 上应已 export，脚本内以环境变量为准。传 `prod`/`test` 以脚本参数为准（可能与 `env` 参数重复，保持一致即可）。
- **mysql CLI**：Worker 基础镜像未必含 `mysql` 客户端；优先用 Python 入口或确认镜像已安装。

### 5.5 单节点 vs 多节点 DAG

**单 Shell 节点（推荐起步）**

- 一个工作流 = 一个 `etl_cmd`
- 业务脚本内部自行串步骤（如 Python 编排器循环执行多段 SQL）

**多 Shell 节点 DAG（细粒度重试）**

- 每个节点复用**同一段 bootstrap**，仅最后 `eval` 的行不同
- 节点间用 DS「前置任务」串联
- 示例结构：

```text
[bootstrap + 步骤 A] → [bootstrap + 步骤 B] → [bootstrap + 步骤 C]
```

若业务脚本支持「只跑某步」的环境变量（如 `ONLY_STEPS=2`），可拆节点而无需拆 SQL 文件。具体变量见各入口脚本文档。

**并行分支**

- 无数据依赖的 L1/L2 可并行多个 Shell 节点（各自 bootstrap + 不同 `etl_cmd`）
- 写同一 `data_source` 或同一宽表时**不要**并行

### 5.6 最简 Shell（无参数，联调用）

不写工作流参数、固定跑 `current` + prod 时：

```bash
set -euo pipefail
cd /opt/data_etl/current
export ETL_SECRET_ENV_FILE=/opt/data_etl_secret/db.env
source sql_scripts/load_env.sh
export DWD_SCHEMA=dwd DIM_SCHEMA=dim ALLOW_PROD=1

# ↓ 换成你的入口
python3 sql_scripts/pdf_pipe/run_pdf_pipe_ds.py
```

### 5.7 调度与运维参数（DS UI）

| 配置项 | 建议 |
|--------|------|
| 超时 | 按最长 SQL 设置；脚本内常有 `query_timeout` |
| 失败重试 | 幂等任务可 1～3 次；非幂等慎用 |
| 告警 | 失败邮件/钉钉 |
| 并发 | 同表/同 `data_source` 串行 |
| 补数 | `code_version=<历史sha>` pin 旧代码；或临时改 `current` 软链 |

---

## 6. 上线前检查清单

### 6.1 平台侧

- [ ] `deploy_component_etl` 成功
- [ ] Worker Pod `Running`，所需 Python 包可 import（见 `requirements.txt`）
- [ ] `/opt/data_etl/current/VERSION` 为预期 commit

### 6.2 Worker 预检

```bash
bash /opt/data_etl/current/ci/preflight_ds_worker.sh
```

### 6.3 工作流侧（与具体业务无关）

- [ ] Shell 在 **Worker** 上执行
- [ ] bootstrap 含 `source sql_scripts/load_env.sh`
- [ ] `env` 与预期 schema 一致（test 勿误写 prod）
- [ ] `etl_cmd` 路径相对于 `repo_root` 存在
- [ ] 试运行成功，退出码 0

### 6.4 本地对照

```bash
source sql_scripts/local.env
export DWD_SCHEMA=dwd DIM_SCHEMA=dim   # 或 test_*
# 与 etl_cmd 相同的命令
```

---

## 7. 日常运维

### 7.1 发布新代码

push `main` → 等 `deploy_component_etl` → `current` 自动更新 → 下次调度即用新代码（`code_version=current` 时）。

### 7.2 回滚代码

- 工作流参数：`code_version=<旧 commit sha>`
- 或节点上：`ln -sfn releases/<旧sha> /opt/data_etl/current`

### 7.3 新增 Python 依赖

改 `docker/ds-worker/requirements.txt` → push → `build_ds_worker_image` → rollout。

### 7.4 更新数据库密码

改 GitLab `MYSQL_PASSWORD` → 重跑 `deploy_component_etl` → 新任务自动读新 Secret。

### 7.5 日志

- **业务日志**：DS UI → 工作流实例 → 任务日志
- **Worker 进程**：`kubectl -n dolphinscheduler logs dolphinscheduler-worker-0 -c dolphinscheduler-worker`

---

## 8. 排障指南

### 8.1 CI / Worker 平台

| 现象 | 处理 |
|------|------|
| deploy 失败 / kubeconfig localhost | 用内网 API 重建 `KUBECONFIG` File 变量 |
| PVC / Secret 未挂载 | 重跑 deploy；检查 StatefulSet volumeMounts |
| 镜像 pull 失败 HTTP/HTTPS | `sudo bash ci/fix_k3s_gitlab_registry.sh` |
| `no users found` 起容器失败 | 检查 ds-worker Dockerfile 是否设了不存在的 USER |
| `ModuleNotFoundError` | rebuild Worker 镜像并 rollout |

### 8.2 海豚任务（通用）

| 现象 | 处理 |
|------|------|
| `缺少 MYSQL_*` / 凭据文件不存在 | bootstrap 是否 `source load_env.sh`；Secret 是否挂载 |
| `command not found: mysql` | 改用 Python 入口或给镜像装客户端 |
| 退出码 2 | 多为 bootstrap 参数错误（`env` 非法等） |
| 退出码 1 | 业务脚本失败；读 DS 日志；本地同 env 复现 |
| 找不到 SQL/脚本 | `code_version` 是否过旧；路径是否相对 `repo_root` |

### 8.3 常用命令

```bash
kubectl -n dolphinscheduler get pod dolphinscheduler-worker-0 -o wide
kubectl -n dolphinscheduler exec dolphinscheduler-worker-0 -c dolphinscheduler-worker -- \
  cat /opt/data_etl/current/VERSION
kubectl -n dolphinscheduler exec dolphinscheduler-worker-0 -c dolphinscheduler-worker -- \
  sh -c 'test -r /opt/data_etl_secret/db.env && echo OK'
```

---

## 9. 附录 A：工作流示例 — PDF 抽取直通链路

> **仅为示例。** 其他 L1 清洗请替换 `etl_cmd`，bootstrap 不变。

| 工作流参数 | 值 |
|------------|-----|
| `etl_repo_base` | `/opt/data_etl` |
| `code_version` | `current` |
| `env` | `prod` |
| `etl_cmd` | `python3 sql_scripts/pdf_pipe/run_pdf_pipe_ds.py` |

入口脚本：`sql_scripts/pdf_pipe/run_pdf_pipe_ds.py`（纯 pymysql，4 步：upsert → classify → eav → l2）。

**可选环境变量**（写在 bootstrap 第 4 步之前，或 DS 环境管理）：

| 变量 | 说明 |
|------|------|
| `SKIP_UPSERT=1` | 跳过 ODS upsert |
| `ONLY_STEPS=2,3,4` | 只跑指定步骤 |

**拆 4 节点 DAG 示例**（每节点 bootstrap 相同，仅 `etl_cmd` 不同）：

| 节点 | `etl_cmd` |
|------|-----------|
| upsert | `ONLY_STEPS=1 python3 sql_scripts/pdf_pipe/run_pdf_pipe_ds.py` |
| classify | `ONLY_STEPS=2 python3 sql_scripts/pdf_pipe/run_pdf_pipe_ds.py` |
| eav | `ONLY_STEPS=3 python3 sql_scripts/pdf_pipe/run_pdf_pipe_ds.py` |
| l2 | `ONLY_STEPS=4 python3 sql_scripts/pdf_pipe/run_pdf_pipe_ds.py` |

更多细节见 [`sql_scripts/dolphinscheduler/README_pdf_pipe.md`](../sql_scripts/dolphinscheduler/README_pdf_pipe.md)（本地草稿，可能未入库）。

---

## 10. 附录 B：其他入口脚本索引

配置新工作流时，在 `sql_scripts/` 下找入口，填入 `etl_cmd`：

| 场景 | 入口示例 |
|------|----------|
| L3 分类 | `bash sql_scripts/1.classify/run_classify.sh prod` |
| 属性标准化 | `bash sql_scripts/2.attribute_standard/run_attr_std.sh prod` |
| 仓库总览 | [`sql_scripts/README.md`](../sql_scripts/README.md) |
| L1 端到端 | [`sql_scripts/L1_STD_PIPELINE.md`](../sql_scripts/L1_STD_PIPELINE.md) |
| test sandbox | `sql_scripts/test/<l1>/run_*.py`（通常先 `env=test`） |

---

## 11. 附录 C：首次全量部署顺序

1. GitLab 配置 `KUBECONFIG` + `MYSQL_*`
2. K3s 节点配置 GitLab HTTP Registry（若需要）：`sudo bash ci/fix_k3s_gitlab_registry.sh`
3. 推送基础 Worker 镜像（若 CI build 拉不到）——见 `docker/ds-worker/README.md`
4. push `main` → `deploy_component_etl`（+ 按需 `build_ds_worker_image`）
5. Worker 上跑 `ci/preflight_ds_worker.sh`
6. 海豚 UI 按 **第 5 节** 创建**第一个**工作流（可先用 **5.6 最简 Shell** 联调）
7. 配置定时与告警

之后新增业务：**复制 bootstrap 模板 → 只改 `etl_cmd` → 新建工作流**，无需改 CI。

---

## 12. 文档索引

| 路径 | 说明 |
|------|------|
| [`ci/README.md`](../ci/README.md) | CI 变量与 deploy |
| [`docker/ds-worker/README.md`](../docker/ds-worker/README.md) | Worker 镜像 |
| [`sql_scripts/load_env.sh`](../sql_scripts/load_env.sh) | Worker 凭据加载 |
| [`ci/preflight_ds_worker.sh`](../ci/preflight_ds_worker.sh) | Worker 预检 |
| [`ci/fix_k3s_gitlab_registry.sh`](../ci/fix_k3s_gitlab_registry.sh) | K3s Registry 一次性配置 |
