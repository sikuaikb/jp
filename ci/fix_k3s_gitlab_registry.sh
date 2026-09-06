#!/usr/bin/env bash
# 在 K3s 节点（ubuntu-21）上一次性配置 GitLab HTTP 私有仓库，使 Worker 能 pull ds-worker 镜像。
# 需 root：sudo bash ci/fix_k3s_gitlab_registry.sh
#
# 根因：GitLab Registry 192.168.19.18:5050 仅 HTTP，K3s containerd 默认 HTTPS →
#   "http: server gave HTTP response to HTTPS client"
set -euo pipefail

REGISTRY="${GITLAB_REGISTRY:-192.168.19.18:5050}"
REGISTRIES_FILE="${K3S_REGISTRIES_FILE:-/etc/rancher/k3s/registries.yaml}"

log() { echo "[INFO] $*"; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "请使用 root 运行: sudo bash $0"

if [ -f "${REGISTRIES_FILE}" ] && grep -qF "${REGISTRY}" "${REGISTRIES_FILE}"; then
  log "${REGISTRY} 已在 ${REGISTRIES_FILE} 中配置，跳过"
  exit 0
fi

read_auth() {
  python3 - "${REGISTRY}" "$@" <<'PY'
import json, base64, sys, pathlib
registry = sys.argv[1]
for cfg in sys.argv[2:]:
    p = pathlib.Path(cfg)
    if not p.exists():
        continue
    auth = json.loads(p.read_text()).get("auths", {}).get(registry, {}).get("auth")
    if auth:
        u, pw = base64.b64decode(auth).decode().split(":", 1)
        print(u)
        print(pw)
        sys.exit(0)
sys.exit(1)
PY
}

mapfile -t _auth < <(read_auth "${REGISTRY}" \
  "/root/.docker/config.json" "/home/ubuntu/.docker/config.json") \
  || fail "未找到 ${REGISTRY} 凭据，请先 docker login ${REGISTRY}"
REGISTRY_USER="${_auth[0]}"
REGISTRY_PASS="${_auth[1]}"
log "registry auth user=${REGISTRY_USER}"

mkdir -p "$(dirname "${REGISTRIES_FILE}")"
if [ -f "${REGISTRIES_FILE}" ]; then
  cp -a "${REGISTRIES_FILE}" "${REGISTRIES_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  log "backed up ${REGISTRIES_FILE}"
fi

# 保留原有 docker.io mirrors（若存在），追加 GitLab HTTP registry
python3 - "${REGISTRIES_FILE}" "${REGISTRY}" "${REGISTRY_USER}" "${REGISTRY_PASS}" <<'PY'
import pathlib, re, sys

path, registry, user, pwd = sys.argv[1:5]
text = path.read_text() if path.exists() else ""

if registry in text:
    print(f"already configured: {registry}")
    sys.exit(0)

gitlab_block = f'''
  "{registry}":
    endpoint:
      - "http://{registry}"
'''
configs_block = f'''
configs:
  "{registry}":
    auth:
      username: {user}
      password: {pwd}
    tls:
      insecure_skip_verify: true
'''

if re.search(r'^mirrors:\s*$', text, re.M):
    text = re.sub(
        r'(^mirrors:\s*\n(?:  .+\n)*)',
        lambda m: m.group(1).rstrip() + gitlab_block,
        text,
        count=1,
        flags=re.M,
    )
else:
    text = 'mirrors:\n' + gitlab_block + text

if 'configs:' not in text:
    text = text.rstrip() + configs_block + '\n'
else:
    text = text.rstrip() + f'''
  "{registry}":
    auth:
      username: {user}
      password: {pwd}
    tls:
      insecure_skip_verify: true
'''

path.write_text(text)
print(f"updated {path}")
PY

log "restarting k3s..."
systemctl restart k3s

log "waiting for kubernetes API..."
for _ in $(seq 1 60); do
  if kubectl get nodes >/dev/null 2>&1; then
    kubectl get nodes
    break
  fi
  sleep 5
done

log "done. 切换 ds-worker 镜像："
echo "  kubectl -n dolphinscheduler set image sts/dolphinscheduler-worker \\"
echo "    dolphinscheduler-worker=${REGISTRY}/jetpave/knowledge-platform/data_etl/ds-worker:stable-etl"
echo "  kubectl -n dolphinscheduler rollout status sts/dolphinscheduler-worker --timeout=600s"
