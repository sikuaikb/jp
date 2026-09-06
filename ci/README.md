# CI/CD：发布 ETL 脚本到 DolphinScheduler Worker

将 Git 仓库按 commit 发布到 Worker 共享 PVC（`/opt/data_etl/current`），数据库凭据经 K8s Secret 挂载（`/opt/data_etl_secret/db.env`），**密码不进 Git**。

**海豚调度完整操作手册**（工作流配置、日常运维、排障）：[`docs/dolphinscheduler_ops_manual.md`](../docs/dolphinscheduler_ops_manual.md)

## 流水线做什么

```text
1. 读取 GitLab File 变量 KUBECONFIG + MYSQL_*
2. 创建/更新 K8s Secret component-etl-db-env
3. ensure Worker 挂载代码 PVC + DB Secret（首次 patch StatefulSet）
4. git archive 当前 commit → PVC releases/<sha>
5. ln -sfn releases/<sha> current
6. 从 Worker Pod 验证代码 + Secret 可读
```

## GitLab CI 变量

### kubeconfig（必填）

| Key | Type | Value |
|-----|------|-------|
| `KUBECONFIG` | **File** | 下面命令输出的 YAML 原文（**不要** base64） |

在**与 shell runner（jp-gitlab-ubuntu）同一内网、能访问真实 K8s API** 的机器上生成 Value（不要用本机 kind/minikube/127.0.0.1）：

```bash
# 先确认 API 地址不是 localhost
kubectl config current-context
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'; echo
# 必须是内网 IP/域名，例如 https://192.168.x.x:6443

kubectl config view --raw --minify
```

GitLab → **Settings → CI/CD → Variables** → Key=`KUBECONFIG`，Type=**File**，粘贴上述输出。

**若 jp-gitlab-ubuntu 上已有可用的 `~/.kube/config`**（指向生产集群），可改用 CI 变量 `USE_RUNNER_KUBECONFIG=true`，并删除 File 变量 `KUBECONFIG`。

请**删除**旧的 `KUBECONFIG_B64`（若仍存在），避免干扰排查。

### MySQL（必填）

| 变量 | 说明 |
|------|------|
| `MYSQL_HOST` | StarRocks FE |
| `MYSQL_PORT` | 通常 9030 |
| `MYSQL_USER` | |
| `MYSQL_PASSWORD` | |

### 可选

| 变量 | 默认 |
|------|------|
| `K8S_NAMESPACE` | dolphinscheduler |
| `WORKER_STS` | dolphinscheduler-worker |
| `WORKER_CONTAINER` | dolphinscheduler-worker |
| `ETL_PVC_NAME` | component-etl-code-pvc |
| `NFS_STORAGE_CLASS` | nfs-client |
| `ETL_BASE` | /opt/data_etl |
| `DB_SECRET_NAME` | component-etl-db-env |
| `DB_SECRET_MOUNT_PATH` | /opt/data_etl_secret |
| `FORCE_WORKER_RESTART` | false |
| `SKIP_WORKER_VERIFY` | false | Worker 未 Running 时设 `true` 仍视为 deploy 成功 |
| `KUBECTL_BIN` | shell runner 上 kubectl 绝对路径（已安装时可指定，跳过下载） |
| `KUBECTL_VERSION` | 自动下载 kubectl 的版本，默认 stable |
| `AUTO_INSTALL_KUBECTL` | true；runner 无 kubectl 时自动下载到 job 临时目录 |
| `KUBECONFIG_PATH` | Runner 本机 kubeconfig 路径（无 File 变量时的备选） |
| `USE_RUNNER_KUBECONFIG` | `true` 时使用 Runner 的 `~/.kube/config` |

## 本地开发 vs Worker

| | 本地 | DS Worker |
|--|------|-----------|
| 代码 | git clone | `/opt/data_etl/current` |
| 凭据 | `sql_scripts/local.env`（gitignore） | `/opt/data_etl_secret/db.env`（K8s Secret） |
| 加载 | `source sql_scripts/local.env` | `source sql_scripts/load_env.sh` |

```bash
cp sql_scripts/local.env.example sql_scripts/local.env
# 编辑 local.env
source sql_scripts/local.env
```

## DS Shell 任务示例（PDF 直通链路）

```bash
set -euo pipefail

cd /opt/data_etl/current
export ETL_SECRET_ENV_FILE="/opt/data_etl_secret/db.env"
source sql_scripts/load_env.sh

python3 sql_scripts/pdf_pipe/run_pdf_pipe_ds.py
```

## 注意

- **shell runner 需能执行 `kubectl`**：脚本默认在 job 内自动下载；若 runner 无外网，请在 `jp-gitlab-ubuntu` 上 `sudo apt install kubectl` 或设置 `KUBECTL_BIN`。
- 首次运行会 **patch** `dolphinscheduler-worker` StatefulSet 增加 volumeMount；Helm 升级可能覆盖，脚本会 idempotent 再 patch。
- 长期建议把 volumeMount 固化进 Helm values。
- `*.sh` 在仓库根 `.gitignore` 中默认忽略；`ci/*.sh`、`docker/ds-worker/*.sh` 已例外入仓。

## DS Worker 扩展镜像（Python 依赖）

| 改什么 | 走哪条 CI |
|--------|-----------|
| SQL / Python 脚本 | `deploy_component_etl` |
| `docker/ds-worker/requirements.txt` 或 `Dockerfile` | `build_ds_worker_image`（**仅这两文件变更时**） |

**不必额外配 CI 变量**：基础镜像写在 `docker/ds-worker/Dockerfile` 的 `ARG BASE_IMAGE`；push 后自动 build/push 到 GitLab Registry。若已配 deploy 用的 `KUBECONFIG` (File)，build 完会**自动 rollout** Worker。

可选：`DS_WORKER_ROLLOUT=false` 只 build 不重启；`BUILD_DS_WORKER_IMAGE=1` 手动 force build（改 CI 脚本时用）。

详见 [`docker/ds-worker/README.md`](../docker/ds-worker/README.md)。
