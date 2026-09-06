#!/usr/bin/env bash
# 构建 DS Worker 扩展镜像（本地或 CI 调用）
#
# 基础镜像：默认读 Dockerfile 的 ARG BASE_IMAGE；仅 override 时设 DS_WORKER_BASE_IMAGE
# 可选：DS_WORKER_IMAGE_REPO / DS_WORKER_TAG / DS_WORKER_STABLE_TAG
#       PUSH=1  ROLLOUT=1（需 KUBECONFIG，见 ci/rollout_ds_worker_image.sh）
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${DIR}/../.." && pwd)"

: "${DS_WORKER_BASE_IMAGE:?missing DS_WORKER_BASE_IMAGE — set env or run via ci/build_ds_worker_image.sh}"

IMAGE_REPO="${DS_WORKER_IMAGE_REPO:-}"
if [ -z "${IMAGE_REPO}" ]; then
  if [ -n "${CI_REGISTRY_IMAGE:-}" ]; then
    IMAGE_REPO="${CI_REGISTRY_IMAGE}/ds-worker"
  else
    IMAGE_REPO="local/ds-worker"
  fi
fi

TAG="${DS_WORKER_TAG:-$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo local)}"
FULL_IMAGE="${IMAGE_REPO}:${TAG}"

log() { echo "[INFO] $*"; }

BUILD_ARGS=(--build-arg "BASE_IMAGE=${DS_WORKER_BASE_IMAGE}")
log "BASE_IMAGE=${DS_WORKER_BASE_IMAGE}"
log "FULL_IMAGE=${FULL_IMAGE}"

docker build \
  "${BUILD_ARGS[@]}" \
  -t "${FULL_IMAGE}" \
  "${DIR}"

log "build OK: ${FULL_IMAGE}"

if [ "${PUSH:-0}" = "1" ]; then
  if [ -n "${CI_REGISTRY:-}" ] && [ -n "${CI_REGISTRY_USER:-}" ] && [ -n "${CI_REGISTRY_PASSWORD:-}" ]; then
    log "docker login ${CI_REGISTRY}"
    echo "${CI_REGISTRY_PASSWORD}" | docker login -u "${CI_REGISTRY_USER}" --password-stdin "${CI_REGISTRY}"
  fi
  docker push "${FULL_IMAGE}"
  log "pushed ${FULL_IMAGE}"
  if [ -n "${DS_WORKER_STABLE_TAG:-}" ]; then
    STABLE="${IMAGE_REPO}:${DS_WORKER_STABLE_TAG}"
    docker tag "${FULL_IMAGE}" "${STABLE}"
    docker push "${STABLE}"
    log "pushed stable tag ${STABLE}"
    FULL_IMAGE="${STABLE}"
  fi
fi

if [ "${ROLLOUT:-0}" = "1" ]; then
  if [ "${PUSH:-0}" != "1" ]; then
    echo "[ERROR] ROLLOUT=1 需要 PUSH=1（集群需拉 registry 镜像）" >&2
    exit 1
  fi
  export DS_WORKER_IMAGE="${FULL_IMAGE}"
  bash "${REPO_ROOT}/ci/rollout_ds_worker_image.sh"
fi

echo "${FULL_IMAGE}" > "${DIR}/.last-built-image"
log "written ${DIR}/.last-built-image"
