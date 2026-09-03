#!/usr/bin/env bash
# 解析 DS Worker 基础镜像（供 docker build 的 BASE_IMAGE）
# stdout 仅输出一行镜像名；日志走 stderr
set -euo pipefail

log() { echo "[INFO] $*" >&2; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

if [ -n "${DS_WORKER_BASE_IMAGE:-}" ]; then
  printf '%s\n' "${DS_WORKER_BASE_IMAGE}"
  exit 0
fi

CI_KUBECONFIG_FROM_GITLAB="${KUBECONFIG:-}"
K8S_NAMESPACE="${K8S_NAMESPACE:-dolphinscheduler}"
WORKER_STS="${WORKER_STS:-dolphinscheduler-worker}"
WORKER_CONTAINER="${WORKER_CONTAINER:-dolphinscheduler-worker}"
WORKER_POD="${WORKER_POD:-${WORKER_STS}-0}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
KUBECONFIG_FILE="${TMP_DIR}/kubeconfig"

resolve_kubeconfig() {
  if [ -n "${CI_KUBECONFIG_FROM_GITLAB}" ] && [ -f "${CI_KUBECONFIG_FROM_GITLAB}" ]; then
    cp "${CI_KUBECONFIG_FROM_GITLAB}" "${KUBECONFIG_FILE}"
  elif [ -n "${KUBECONFIG_PATH:-}" ] && [ -f "${KUBECONFIG_PATH}" ]; then
    cp "${KUBECONFIG_PATH}" "${KUBECONFIG_FILE}"
  elif [ "${USE_RUNNER_KUBECONFIG:-false}" = "true" ] && [ -f "${HOME}/.kube/config" ]; then
    cp "${HOME}/.kube/config" "${KUBECONFIG_FILE}"
  else
    fail "missing DS_WORKER_BASE_IMAGE and no kubeconfig (set KUBECONFIG File or DS_WORKER_BASE_IMAGE)"
  fi
  chmod 600 "${KUBECONFIG_FILE}"
  export KUBECONFIG="${KUBECONFIG_FILE}"
}

# shellcheck source=ci/ensure_kubectl.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ensure_kubectl.sh"
ENSURE_KUBECTL_TMP_DIR="${TMP_DIR}"

resolve_kubeconfig
ensure_kubectl || fail "kubectl unavailable"

IMAGE="$(
  kubectl -n "${K8S_NAMESPACE}" get pod "${WORKER_POD}" \
    -o jsonpath="{.spec.containers[?(@.name=='${WORKER_CONTAINER}')].image}" 2>/dev/null || true
)"

[ -n "${IMAGE}" ] || fail "cannot read worker image from pod ${WORKER_POD}"

if [[ "${IMAGE}" == docker.io/* ]]; then
  log "worker image uses docker.io: ${IMAGE} (build 时将尝试 GitLab Registry 同名镜像)"
fi

log "resolved worker base image: ${IMAGE}"
printf '%s\n' "${IMAGE}"
