#!/usr/bin/env bash
# 在 k3s 节点（ubuntu-21）上：把 Worker 基础镜像推到 GitLab Registry
#
# 用法（在 ubuntu-21 上）：
#   REG=192.168.19.18:5050/jetpave/knowledge-platform/data_etl \
#   TAG=3.3.2 \
#   bash docker/ds-worker/push_base_image.sh
#
# 需要：docker login 192.168.19.18:5050（GitLab 用户名 + PAT）
set -euo pipefail

REG="${REG:-192.168.19.18:5050/jetpave/knowledge-platform/data_etl}"
TAG="${TAG:-3.3.2}"
SRC="docker.io/library/custom-dolphinscheduler-worker:${TAG}"
DEST="${REG}/custom-dolphinscheduler-worker:${TAG}"

log() { echo "[INFO] $*"; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

if docker image inspect "${SRC}" >/dev/null 2>&1; then
  log "found in docker: ${SRC}"
else
  log "not in docker, try export from k3s containerd..."
  command -v k3s >/dev/null 2>&1 || fail "k3s not found and docker image missing: ${SRC}"
  sudo k3s ctr images ls | grep -F "custom-dolphinscheduler-worker" || true
  sudo k3s ctr images export /tmp/worker-base.tar "${SRC}" \
    || fail "ctr export failed; check: sudo k3s ctr images ls | grep dolphin"
  docker load -i /tmp/worker-base.tar
fi

docker image inspect "${SRC}" >/dev/null 2>&1 || fail "still no image: ${SRC}"

log "tag ${SRC} -> ${DEST}"
docker tag "${SRC}" "${DEST}"

log "push ${DEST} (ensure: docker login ${REG%%/*})"
docker push "${DEST}"

log "OK pushed ${DEST}"
log "verify: docker pull ${DEST}"
