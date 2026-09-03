#!/usr/bin/env bash
# 将 DS Worker StatefulSet 切换到新镜像并滚动重启
#
# 依赖：与 ci/deploy_to_ds_worker.sh 相同的 KUBECONFIG（GitLab File 变量）或 USE_RUNNER_KUBECONFIG
# 用法：
#   DS_WORKER_IMAGE=registry.example.com/ds-worker:stable-etl bash ci/rollout_ds_worker_image.sh
set -euo pipefail

: "${DS_WORKER_IMAGE:?missing DS_WORKER_IMAGE}"

CI_KUBECONFIG_FROM_GITLAB="${KUBECONFIG:-}"
K8S_NAMESPACE="${K8S_NAMESPACE:-dolphinscheduler}"
WORKER_STS="${WORKER_STS:-dolphinscheduler-worker}"
WORKER_CONTAINER="${WORKER_CONTAINER:-dolphinscheduler-worker}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
KUBECONFIG_FILE="${TMP_DIR}/kubeconfig"

log() { echo "[INFO] $*"; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

resolve_kubeconfig() {
  if [ -n "${CI_KUBECONFIG_FROM_GITLAB}" ] && [ -f "${CI_KUBECONFIG_FROM_GITLAB}" ]; then
    cp "${CI_KUBECONFIG_FROM_GITLAB}" "${KUBECONFIG_FILE}"
  elif [ -n "${KUBECONFIG_PATH:-}" ] && [ -f "${KUBECONFIG_PATH}" ]; then
    cp "${KUBECONFIG_PATH}" "${KUBECONFIG_FILE}"
  elif [ "${USE_RUNNER_KUBECONFIG:-false}" = "true" ] && [ -f "${HOME}/.kube/config" ]; then
    cp "${HOME}/.kube/config" "${KUBECONFIG_FILE}"
  else
    fail "missing kubeconfig (GitLab File KUBECONFIG / KUBECONFIG_PATH / USE_RUNNER_KUBECONFIG)"
  fi
  chmod 600 "${KUBECONFIG_FILE}"
  export KUBECONFIG="${KUBECONFIG_FILE}"
}

# shellcheck source=ci/ensure_kubectl.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ensure_kubectl.sh"
ENSURE_KUBECTL_TMP_DIR="${TMP_DIR}"
ensure_kubectl || fail "kubectl unavailable"

resolve_kubeconfig

log "rollout ${WORKER_STS} -> ${DS_WORKER_IMAGE}"

kubectl -n "${K8S_NAMESPACE}" set image "sts/${WORKER_STS}" \
  "${WORKER_CONTAINER}=${DS_WORKER_IMAGE}"

ROLLOUT_TIMEOUT="${DS_WORKER_ROLLOUT_TIMEOUT:-600s}"
if ! kubectl -n "${K8S_NAMESPACE}" rollout status "sts/${WORKER_STS}" --timeout="${ROLLOUT_TIMEOUT}"; then
  echo "[ERROR] rollout timeout (${ROLLOUT_TIMEOUT})" >&2
  echo "[ERROR] --- pod status ---" >&2
  kubectl -n "${K8S_NAMESPACE}" get pods -l "app.kubernetes.io/name=${WORKER_STS}" -o wide 2>/dev/null \
    || kubectl -n "${K8S_NAMESPACE}" get pods | grep -F "${WORKER_STS}" >&2 || true
  POD="${WORKER_STS}-0"
  kubectl -n "${K8S_NAMESPACE}" describe pod "${POD}" 2>/dev/null | tail -40 >&2 || true
  fail "$(cat <<EOF
Worker rollout failed. 镜像已 push 成功，常见原因：节点拉不下 GitLab 私有镜像 (ImagePullBackOff)。

在 ubuntu-21 检查：
  kubectl -n ${K8S_NAMESPACE} get pod ${POD}
  kubectl -n ${K8S_NAMESPACE} describe pod ${POD} | tail -30

若见 ImagePullBackOff，为 Worker 配置 imagePullSecret 后重试 rollout：
  kubectl -n ${K8S_NAMESPACE} create secret docker-registry gitlab-registry-secret \\
    --docker-server=192.168.19.18:5050 --docker-username=<user> --docker-password=<PAT> \\
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n ${K8S_NAMESPACE} patch sts ${WORKER_STS} --type=json -p='[
    {"op":"add","path":"/spec/template/spec/imagePullSecrets","value":[{"name":"gitlab-registry-secret"}]}
  ]'
  kubectl -n ${K8S_NAMESPACE} rollout restart sts/${WORKER_STS}
EOF
)"
fi

POD="${WORKER_STS}-0"
kubectl -n "${K8S_NAMESPACE}" exec "${POD}" -c "${WORKER_CONTAINER}" -- \
  python3 -c "import pymysql; print('pymysql OK', pymysql.__version__)"

log "rollout finished: ${DS_WORKER_IMAGE}"
