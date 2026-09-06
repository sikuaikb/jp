# DS Worker 扩展镜像

在 Worker 基础镜像上叠加 ETL 所需的 Python 依赖。

## 改什么、改哪里

| 需求 | 改的文件 |
|------|----------|
| 加 / 升级 Python 包 | `requirements.txt` |
| 换 Worker 基础镜像版本 | 一般**不用改文件** — CI 自动读集群 Worker 当前镜像；特殊时设 `DS_WORKER_BASE_IMAGE` |

**不需要**在 GitLab 再配一堆变量。

## 日常：加 Python 依赖

1. 编辑 `requirements.txt`
2. push `main` → 仅当 **`requirements.txt` 或 `Dockerfile` 有变更** 时 CI job `build_ds_worker_image` 才会跑（不是每次 push 都 build）
3. 若项目已配 deploy 用的 **`KUBECONFIG` (File)**，会顺带 rollout Worker
4. 重跑海豚任务

## GitLab CI 变量（极简）

| 变量 | 是否必填 | 说明 |
|------|----------|------|
| `KUBECONFIG` (File) | deploy 必填；build rollout 复用 | 与 `deploy_component_etl` 共用 |
| `MYSQL_*` | 仅 deploy 需要 | build 镜像不需要 |
| `DS_WORKER_ROLLOUT` | 否 | 默认 `auto`：有 KUBECONFIG 就 rollout；设 `false` 只 build 不重启 |
| `DS_WORKER_BASE_IMAGE` | 否 | 临时覆盖 Dockerfile 的 `BASE_IMAGE`，一般不用 |
| `BUILD_DS_WORKER_IMAGE=1` | 否 | 手动 force 触发 build |

镜像推到 GitLab 内置 **`$CI_REGISTRY_IMAGE/ds-worker`**，稳定 tag 默认 **`stable-etl`**。

## 本地 build

```bash
bash docker/ds-worker/build.sh
docker run --rm local/ds-worker:<sha> python3 -c "import pymysql"
```

## 升级基础镜像

CI 会从 `dolphinscheduler-worker-0` **自动读取**当前镜像作为 `BASE_IMAGE`（内网 Registry 全路径，不走 docker.io）。

手动指定：`DS_WORKER_BASE_IMAGE=192.168.19.18:5050/.../custom-dolphinscheduler-worker:3.3.2`

## 一次性：推送基础镜像到 GitLab（k3s 节点上常见）

Worker Pod 可能是 `docker.io/library/custom-dolphinscheduler-worker:3.3.2`，镜像在 **containerd** 不在 docker。

在 **ubuntu-21**（k3s 节点）执行：

```bash
# 1) 找镜像（k3s）
sudo k3s ctr images ls | grep -i custom-dolphinscheduler

# 2) 导出 → 载入 docker（若无 docker 短名）
sudo k3s ctr images export /tmp/worker-base.tar docker.io/library/custom-dolphinscheduler-worker:3.3.2
docker load -i /tmp/worker-base.tar

# 3) 登录 GitLab（用 Personal Access Token，不要用过期 gitlab-ci-token）
docker login 192.168.19.18:5050

# 4) tag + push 到 data_etl 项目（CI fallback 路径）
REG=192.168.19.18:5050/jetpave/knowledge-platform/data_etl
docker tag docker.io/library/custom-dolphinscheduler-worker:3.3.2 \
  "${REG}/custom-dolphinscheduler-worker:3.3.2"
docker push "${REG}/custom-dolphinscheduler-worker:3.3.2"
```

然后 GitLab **Retry** `build_ds_worker_image`（或 `BUILD_DS_WORKER_IMAGE=1`）。

## 常见 build 失败

| 报错 | 原因 | 处理 |
|------|------|------|
| `No such image: custom-dolphinscheduler-worker` | 本地 docker 无短名 | 用上节从 containerd 导出 |
| `docker.io/...` pull 失败 | Runner 拉不到 docker.io | push 到 GitLab Registry（上节） |

## 与 ETL 代码发布

| CI job | 更新 |
|--------|------|
| `deploy_component_etl` | `/opt/data_etl/current` 脚本 |
| `build_ds_worker_image` | Worker 容器内 Python 环境 |

## 排查

build 成功后若 rollout 超时，常见两类原因：

1. **K3s 拉 GitLab HTTP 仓库失败**（`http: server gave HTTP response to HTTPS client`）→ 在节点执行 `sudo bash ci/fix_k3s_gitlab_registry.sh`（或见 rollout 失败日志）。
2. **镜像 USER 不存在**（`no users found`）→ `docker/ds-worker/Dockerfile` 勿设不存在的 `USER dolphinscheduler`；基础镜像无该用户。
