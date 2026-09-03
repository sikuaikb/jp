#!/usr/bin/env bash
# GitLab CI：构建并 push DS Worker 扩展镜像；有 KUBECONFIG 时默认滚动 Worker
set -euo pipefail

log() { echo "[INFO] $*" >&2; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || fail "shell runner 需要 docker"

if [ -n "${CI_REGISTRY:-}" ] && [ -n "${CI_REGISTRY_USER:-}" ] && [ -n "${CI_REGISTRY_PASSWORD:-}" ]; then
  log "docker login ${CI_REGISTRY}"
  echo "${CI_REGISTRY_PASSWORD}" | docker login -u "${CI_REGISTRY_USER}" --password-stdin "${CI_REGISTRY}"
fi

# 默认从 GitLab Registry 拉已 push 的基础镜像，不依赖 kubectl（避免 dl.k8s.io 超时）
if [ -z "${DS_WORKER_BASE_IMAGE:-}" ]; then
  if [ "${DS_WORKER_USE_KUBECTL_RESOLVE:-false}" = "true" ]; then
    RESOLVE_OUT="$(mktemp)"
    bash ci/resolve_ds_worker_base_image.sh > "${RESOLVE_OUT}" || fail "failed to resolve DS_WORKER_BASE_IMAGE via kubectl"
    DS_WORKER_BASE_IMAGE="$(head -1 "${RESOLVE_OUT}" | tr -d '\r\n')"
    rm -f "${RESOLVE_OUT}"
  elif [ -n "${CI_REGISTRY_IMAGE:-}" ]; then
    DS_WORKER_BASE_TAG="${DS_WORKER_BASE_TAG:-3.3.2}"
    DS_WORKER_BASE_IMAGE="${CI_REGISTRY_IMAGE}/custom-dolphinscheduler-worker:${DS_WORKER_BASE_TAG}"
    log "DS_WORKER_BASE_IMAGE from GitLab Registry default (tag=${DS_WORKER_BASE_TAG})"
  else
    fail "set DS_WORKER_BASE_IMAGE or run in GitLab CI with Container Registry"
  fi
fi
export DS_WORKER_BASE_IMAGE
[ -n "${DS_WORKER_BASE_IMAGE}" ] || fail "DS_WORKER_BASE_IMAGE is empty"
log "DS_WORKER_BASE_IMAGE=${DS_WORKER_BASE_IMAGE}"

log "docker pull base image..."
docker pull "${DS_WORKER_BASE_IMAGE}" || fail "$(cat <<EOF
cannot pull base image: ${DS_WORKER_BASE_IMAGE}

在 ubuntu-21 推送基础镜像后重试：
  REG=192.168.19.18:5050/jetpave/knowledge-platform/data_etl TAG=3.3.2 \\
    bash docker/ds-worker/push_base_image.sh
EOF
)"

export PUSH=1
export DS_WORKER_TAG="${DS_WORKER_TAG:-${CI_COMMIT_SHORT_SHA}}"
export DS_WORKER_STABLE_TAG="${DS_WORKER_STABLE_TAG:-stable-etl}"

if [ "${DS_WORKER_ROLLOUT:-auto}" = "auto" ]; then
  if [ -n "${KUBECONFIG:-}" ] && [ -f "${KUBECONFIG}" ]; then
    export ROLLOUT=1
  else
    export ROLLOUT=0
  fi
elif [ "${DS_WORKER_ROLLOUT}" = "true" ]; then
  export ROLLOUT=1
else
  export ROLLOUT=0
fi

bash docker/ds-worker/build.sh
