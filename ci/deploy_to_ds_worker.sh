#!/usr/bin/env bash
# 将当前 Git commit 发布到 DS Worker 共享 PVC，并 ensure K8s Secret / 挂载。
#
# kubeconfig：GitLab CI 变量 KUBECONFIG（Type=File，粘贴 kubectl config view --raw --minify）
# 必填：MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASSWORD
# 详见 ci/README.md
set -euo pipefail

: "${MYSQL_HOST:?missing MYSQL_HOST}"
: "${MYSQL_PORT:?missing MYSQL_PORT}"
: "${MYSQL_USER:?missing MYSQL_USER}"
: "${MYSQL_PASSWORD:?missing MYSQL_PASSWORD}"

# GitLab File 变量在 job 内把 KUBECONFIG 设为临时文件路径；先保存，避免后续 export 覆盖
CI_KUBECONFIG_FROM_GITLAB="${KUBECONFIG:-}"
CI_KUBE_CONFIG_FROM_GITLAB="${KUBE_CONFIG:-}"

K8S_NAMESPACE="${K8S_NAMESPACE:-dolphinscheduler}"
WORKER_STS="${WORKER_STS:-dolphinscheduler-worker}"
WORKER_CONTAINER="${WORKER_CONTAINER:-dolphinscheduler-worker}"

ETL_PVC_NAME="${ETL_PVC_NAME:-component-etl-code-pvc}"
NFS_STORAGE_CLASS="${NFS_STORAGE_CLASS:-nfs-client}"
ETL_BASE="${ETL_BASE:-/opt/data_etl}"

DB_SECRET_NAME="${DB_SECRET_NAME:-component-etl-db-env}"
DB_SECRET_MOUNT_PATH="${DB_SECRET_MOUNT_PATH:-/opt/data_etl_secret}"

FORCE_WORKER_RESTART="${FORCE_WORKER_RESTART:-false}"
USE_RUNNER_KUBECONFIG="${USE_RUNNER_KUBECONFIG:-false}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

KUBECONFIG_FILE="${TMP_DIR}/kubeconfig"
DB_ENV_FILE="${TMP_DIR}/db.env"
TARBALL="${TMP_DIR}/repo.tgz"

log() { echo "[INFO] $*"; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

shell_quote() {
  printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

kubectl_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    *) fail "unsupported arch for kubectl auto-install: $(uname -m)" ;;
  esac
}

ensure_kubectl() {
  if [ -n "${KUBECTL_BIN:-}" ] && [ -x "${KUBECTL_BIN}" ]; then
    export PATH="$(dirname "${KUBECTL_BIN}"):${PATH}"
  fi

  if command -v kubectl >/dev/null 2>&1; then
    log "kubectl: $(command -v kubectl)"
    return 0
  fi

  for candidate in /usr/local/bin/kubectl /usr/bin/kubectl /snap/bin/kubectl; do
    if [ -x "${candidate}" ]; then
      export PATH="$(dirname "${candidate}"):${PATH}"
      log "kubectl: ${candidate}"
      return 0
    fi
  done

  if [ "${AUTO_INSTALL_KUBECTL:-true}" != "true" ]; then
    fail "kubectl not found. Install on shell runner, set KUBECTL_BIN=/path/to/kubectl, or AUTO_INSTALL_KUBECTL=true"
  fi

  command -v curl >/dev/null 2>&1 || fail "kubectl not found and curl missing; install kubectl on shell runner"

  local arch ver bin_url dest
  arch="$(kubectl_arch)"
  ver="${KUBECTL_VERSION:-}"
  if [ -z "${ver}" ]; then
    log "fetching kubectl stable version..."
    ver="$(curl -fsSL --max-time 30 https://dl.k8s.io/release/stable.txt)" \
      || fail "cannot fetch kubectl version; set KUBECTL_VERSION or install kubectl on runner"
  fi
  bin_url="https://dl.k8s.io/release/${ver}/bin/linux/${arch}/kubectl"
  dest="${TMP_DIR}/kubectl"
  log "kubectl not on runner; downloading ${ver} (${arch})..."
  curl -fsSL --max-time 180 "${bin_url}" -o "${dest}" \
    || fail "kubectl download failed: ${bin_url}. Install kubectl on shell runner or set KUBECTL_BIN"
  chmod +x "${dest}"
  export PATH="${TMP_DIR}:${PATH}"
  log "kubectl installed to ${dest}"
  kubectl version --client=true 2>/dev/null | head -1 || true
}

validate_kubeconfig_cluster() {
  local ctx server
  ctx="$(kubectl config current-context 2>/dev/null || true)"
  server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)"
  log "kubeconfig context: ${ctx:-<unknown>}"
  log "kubeconfig server: ${server:-<unknown>}"

  case "${server}" in
    https://127.0.0.1:*|http://127.0.0.1:*|https://localhost:*|http://localhost:*)
      fail "$(cat <<EOF
kubeconfig API server is localhost (${server}).
CI shell runner (jp-gitlab-ubuntu) cannot reach your laptop/local kind/minikube.

Fix (pick one):
  1) Regenerate GitLab File KUBECONFIG on a node that can reach the real cluster
     (bastion / K8s master / same LAN as runner), then verify:
       kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'; echo
     server must be internal IP/DNS (e.g. https://192.168.x.x:6443), NOT 127.0.0.1

  2) If jp-gitlab-ubuntu already has ~/.kube/config for prod cluster:
     delete File KUBECONFIG, set USE_RUNNER_KUBECONFIG=true
EOF
)"
      ;;
  esac
}

kubectl_check_cluster() {
  if kubectl get ns "${K8S_NAMESPACE}" >/dev/null 2>&1; then
    return 0
  fi
  local server err
  server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)"
  err="$(kubectl get ns "${K8S_NAMESPACE}" 2>&1 || true)"
  fail "$(cat <<EOF
cannot reach Kubernetes API (namespace=${K8S_NAMESPACE}, server=${server:-<unknown>}).
${err}

Check: runner jp-gitlab-ubuntu must reach API server (network/firewall/VPN).
Regenerate KUBECONFIG File variable from a host inside the cluster network.
EOF
)"
}

validate_kubeconfig_file() {
  if [ ! -s "${KUBECONFIG_FILE}" ]; then
    fail "kubeconfig file is empty: ${KUBECONFIG_FILE}"
  fi
  if ! grep -qE '^(apiVersion|kind):' "${KUBECONFIG_FILE}"; then
    fail "kubeconfig missing apiVersion/kind — check cluster access file content"
  fi
}

copy_kubeconfig_from() {
  local src="$1"
  local label="$2"
  cp "${src}" "${KUBECONFIG_FILE}"
  chmod 600 "${KUBECONFIG_FILE}"
  validate_kubeconfig_file
  log "kubeconfig loaded from ${label}: ${src}"
}

resolve_kubeconfig() {
  log "resolve kubeconfig: CI_KUBECONFIG=${CI_KUBECONFIG_FROM_GITLAB:-<unset>} KUBECONFIG_PATH=${KUBECONFIG_PATH:-<unset>} USE_RUNNER_KUBECONFIG=${USE_RUNNER_KUBECONFIG}"

  # 1) GitLab File 变量 KUBECONFIG / KUBE_CONFIG（Type=File → 值为临时文件路径）
  local file_var
  for file_var in "${CI_KUBECONFIG_FROM_GITLAB}" "${CI_KUBE_CONFIG_FROM_GITLAB}"; do
    if [ -z "${file_var}" ]; then
      continue
    fi
    if [ -f "${file_var}" ]; then
      copy_kubeconfig_from "${file_var}" "GitLab File variable"
      return 0
    fi
    if printf '%s' "${file_var}" | grep -qE '^(apiVersion:|kind:)'; then
      log "KUBECONFIG variable looks like inline YAML; ensure Type=File in GitLab CI settings"
      printf '%s' "${file_var}" > "${KUBECONFIG_FILE}"
      chmod 600 "${KUBECONFIG_FILE}"
      validate_kubeconfig_file
      return 0
    fi
    fail "GitLab variable KUBECONFIG is set but not a readable file: ${file_var}. Use Type=File and paste: kubectl config view --raw --minify"
  done

  # 2) Runner 上固定路径
  if [ -n "${KUBECONFIG_PATH:-}" ] && [ -f "${KUBECONFIG_PATH}" ]; then
    copy_kubeconfig_from "${KUBECONFIG_PATH}" "KUBECONFIG_PATH"
    return 0
  fi

  # 3) Shell Runner 本机 ~/.kube/config（需显式开启）
  if [ "${USE_RUNNER_KUBECONFIG}" = "true" ] && [ -f "${HOME}/.kube/config" ]; then
    copy_kubeconfig_from "${HOME}/.kube/config" "runner ~/.kube/config"
    return 0
  fi

  # 4) KUBECONFIG_B64
  if [ -n "${KUBECONFIG_B64:-}" ]; then
    if printf '%s' "${KUBECONFIG_B64}" | grep -qE '^(apiVersion:|kind:)'; then
      log "KUBECONFIG_B64 looks like raw kubeconfig YAML (not base64); using as-is"
      printf '%s' "${KUBECONFIG_B64}" > "${KUBECONFIG_FILE}"
      chmod 600 "${KUBECONFIG_FILE}"
      validate_kubeconfig_file
      return 0
    fi

    local b64_clean
    b64_clean="$(printf '%s' "${KUBECONFIG_B64}" | tr -d '[:space:]')"
    if [ -z "${b64_clean}" ]; then
      fail "KUBECONFIG_B64 is empty after stripping whitespace"
    fi
    if ! printf '%s' "${b64_clean}" | base64 -d > "${KUBECONFIG_FILE}" 2>"${TMP_DIR}/b64.err"; then
      echo "[ERROR] base64 decode failed (len=${#b64_clean}):" >&2
      cat "${TMP_DIR}/b64.err" >&2 || true
      fail "$(cat <<EOF
No valid kubeconfig source. Pick ONE:

  A) GitLab File variable (recommended)
     Key: KUBECONFIG  Type: File  Value: paste full kubeconfig YAML

  B) Runner local file
     Set KUBECONFIG_PATH=/path/to/config
     OR USE_RUNNER_KUBECONFIG=true if ~/.kube/config exists on shell runner

  C) Base64 variable
     On a machine with cluster access: base64 -w0 ~/.kube/config
     Paste the single-line output into KUBECONFIG_B64 (NOT raw YAML)
EOF
)"
    fi
    chmod 600 "${KUBECONFIG_FILE}"
    validate_kubeconfig_file
    log "kubeconfig loaded from KUBECONFIG_B64"
    return 0
  fi

  fail "$(cat <<EOF
missing kubeconfig. Configure GitLab CI variable:
  Key: KUBECONFIG   Type: File
  Value: output of   kubectl config view --raw --minify
Remove obsolete KUBECONFIG_B64 if present.
Fallbacks: KUBECONFIG_PATH or USE_RUNNER_KUBECONFIG=true
EOF
)"
}

# --- kubeconfig ---
resolve_kubeconfig
export KUBECONFIG="${KUBECONFIG_FILE}"

ensure_kubectl
validate_kubeconfig_cluster
kubectl_check_cluster
log "K8s namespace: ${K8S_NAMESPACE}"

# --- git version ---
GIT_SHA="${CI_COMMIT_SHA:-${GITHUB_SHA:-$(git rev-parse HEAD)}}"
GIT_SHORT="$(echo "${GIT_SHA}" | cut -c1-12)"
log "Git SHA: ${GIT_SHA}"
git rev-parse --is-inside-work-tree >/dev/null

# --- DB Secret ---
{
  echo "export MYSQL_HOST=$(shell_quote "${MYSQL_HOST}")"
  echo "export MYSQL_PORT=$(shell_quote "${MYSQL_PORT}")"
  echo "export MYSQL_USER=$(shell_quote "${MYSQL_USER}")"
  echo "export MYSQL_PASSWORD=$(shell_quote "${MYSQL_PASSWORD}")"
  echo 'export STARROCKS_HOST="${MYSQL_HOST}"'
  echo 'export STARROCKS_PORT="${MYSQL_PORT}"'
  echo 'export STARROCKS_USER="${MYSQL_USER}"'
  echo 'export STARROCKS_PASSWORD="${MYSQL_PASSWORD}"'
} > "${DB_ENV_FILE}"
chmod 600 "${DB_ENV_FILE}"

kubectl -n "${K8S_NAMESPACE}" \
  create secret generic "${DB_SECRET_NAME}" \
  --from-file=db.env="${DB_ENV_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f -
log "DB Secret applied: ${DB_SECRET_NAME}"

# --- PVC ---
if ! kubectl -n "${K8S_NAMESPACE}" get pvc "${ETL_PVC_NAME}" >/dev/null 2>&1; then
  log "PVC not found, creating: ${ETL_PVC_NAME}"
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${ETL_PVC_NAME}
  namespace: ${K8S_NAMESPACE}
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ${NFS_STORAGE_CLASS}
  resources:
    requests:
      storage: 20Gi
EOF
fi

log "Waiting PVC Bound: ${ETL_PVC_NAME}"
for _ in $(seq 1 60); do
  PVC_STATUS="$(kubectl -n "${K8S_NAMESPACE}" get pvc "${ETL_PVC_NAME}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  [ "${PVC_STATUS}" = "Bound" ] && break
  sleep 2
done
PVC_STATUS="$(kubectl -n "${K8S_NAMESPACE}" get pvc "${ETL_PVC_NAME}" -o jsonpath='{.status.phase}')"
[ "${PVC_STATUS}" = "Bound" ] || fail "PVC not Bound: ${ETL_PVC_NAME}, status=${PVC_STATUS}"
log "PVC is Bound: ${ETL_PVC_NAME}"

# --- patch Worker mounts (idempotent) ---
NEED_RESTART="false"

has_mount() {
  local mount_path="$1"
  kubectl -n "${K8S_NAMESPACE}" get sts "${WORKER_STS}" \
    -o jsonpath="{range .spec.template.spec.containers[?(@.name=='${WORKER_CONTAINER}')].volumeMounts[*]}{.mountPath}{'\n'}{end}" \
    | grep -Fx "${mount_path}" || true
}

if [ -z "$(has_mount "${ETL_BASE}")" ]; then
  log "Patching Worker to mount ETL PVC: ${ETL_BASE}"
  kubectl -n "${K8S_NAMESPACE}" patch sts "${WORKER_STS}" --type='json' -p="[
    {\"op\":\"add\",\"path\":\"/spec/template/spec/volumes/-\",\"value\":{\"name\":\"component-etl-code\",\"persistentVolumeClaim\":{\"claimName\":\"${ETL_PVC_NAME}\"}}},
    {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/volumeMounts/-\",\"value\":{\"name\":\"component-etl-code\",\"mountPath\":\"${ETL_BASE}\"}}
  ]"
  NEED_RESTART="true"
else
  log "ETL PVC mount already exists: ${ETL_BASE}"
fi

if [ -z "$(has_mount "${DB_SECRET_MOUNT_PATH}")" ]; then
  log "Patching Worker to mount DB Secret: ${DB_SECRET_MOUNT_PATH}"
  kubectl -n "${K8S_NAMESPACE}" patch sts "${WORKER_STS}" --type='json' -p="[
    {\"op\":\"add\",\"path\":\"/spec/template/spec/volumes/-\",\"value\":{\"name\":\"component-etl-db-env\",\"secret\":{\"secretName\":\"${DB_SECRET_NAME}\",\"defaultMode\":256}}},
    {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/volumeMounts/-\",\"value\":{\"name\":\"component-etl-db-env\",\"mountPath\":\"${DB_SECRET_MOUNT_PATH}\",\"readOnly\":true}}
  ]"
  NEED_RESTART="true"
else
  log "DB Secret mount already exists: ${DB_SECRET_MOUNT_PATH}"
fi

if [ "${NEED_RESTART}" = "true" ] || [ "${FORCE_WORKER_RESTART}" = "true" ]; then
  log "Restarting Worker StatefulSet: ${WORKER_STS}"
  kubectl -n "${K8S_NAMESPACE}" rollout restart "sts/${WORKER_STS}"
  kubectl -n "${K8S_NAMESPACE}" rollout status "sts/${WORKER_STS}" --timeout=300s
else
  log "Worker restart skipped"
fi

# --- deploy pod on PVC ---
DEPLOY_POD="component-etl-deploy-${GIT_SHORT}"
kubectl -n "${K8S_NAMESPACE}" delete pod "${DEPLOY_POD}" --ignore-not-found=true >/dev/null 2>&1 || true

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${DEPLOY_POD}
  namespace: ${K8S_NAMESPACE}
spec:
  restartPolicy: Never
  containers:
    - name: deploy
      image: alpine:3.20
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: etl-code
          mountPath: ${ETL_BASE}
  volumes:
    - name: etl-code
      persistentVolumeClaim:
        claimName: ${ETL_PVC_NAME}
EOF

kubectl -n "${K8S_NAMESPACE}" wait --for=condition=Ready --timeout=120s "pod/${DEPLOY_POD}"
log "Deploy pod ready: ${DEPLOY_POD}"

git archive --format=tar.gz -o "${TARBALL}" HEAD
kubectl -n "${K8S_NAMESPACE}" cp "${TARBALL}" "${DEPLOY_POD}:/tmp/repo.tgz"

kubectl -n "${K8S_NAMESPACE}" exec "${DEPLOY_POD}" -- sh -lc "
set -eu
mkdir -p '${ETL_BASE}/releases'
RELEASE_TMP='${ETL_BASE}/releases/${GIT_SHA}.tmp'
RELEASE_DIR='${ETL_BASE}/releases/${GIT_SHA}'
rm -rf \"\${RELEASE_TMP}\" \"\${RELEASE_DIR}\"
mkdir -p \"\${RELEASE_TMP}\"
tar -xzf /tmp/repo.tgz -C \"\${RELEASE_TMP}\"
echo '${GIT_SHA}' > \"\${RELEASE_TMP}/VERSION\"
chmod +x \"\${RELEASE_TMP}\"/ci/*.sh 2>/dev/null || true
find \"\${RELEASE_TMP}\"/sql_scripts -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
mv \"\${RELEASE_TMP}\" \"\${RELEASE_DIR}\"
cd '${ETL_BASE}'
ln -sfn 'releases/${GIT_SHA}' current
echo '[INFO] current ->' \$(readlink current)
echo '[INFO] VERSION=' \$(cat current/VERSION)
test -f '${ETL_BASE}/current/sql_scripts/load_env.sh'
test -f '${ETL_BASE}/current/sql_scripts/pdf_pipe/run_pdf_pipe_ds.py'
echo '[OK] deploy pod: code layout verified'
"

# --- verify from Worker (fallback: deploy pod 已校验代码布局) ---
find_worker_pod() {
  kubectl -n "${K8S_NAMESPACE}" get pods \
    --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>"${TMP_DIR}/worker-pods.err" \
    | grep -E "^${WORKER_STS}-[0-9]+$" \
    | head -1
}

WORKER_POD="$(find_worker_pod || true)"
if [ -z "${WORKER_POD}" ]; then
  echo "[WARN] Running Worker pod not found for sts ${WORKER_STS}" >&2
  kubectl -n "${K8S_NAMESPACE}" get pods -o wide >&2 || true
  [ -f "${TMP_DIR}/worker-pods.err" ] && cat "${TMP_DIR}/worker-pods.err" >&2 || true
  if [ "${SKIP_WORKER_VERIFY:-false}" = "true" ]; then
    log "SKIP_WORKER_VERIFY=true — code deployed to PVC; fix Worker and re-verify manually"
    kubectl -n "${K8S_NAMESPACE}" delete pod "${DEPLOY_POD}" --ignore-not-found=true --wait=false
    log "Deploy finished (PVC only): ${GIT_SHA}"
    exit 0
  fi
  fail "Worker pod not Running; code is on PVC but integration verify skipped. Fix Worker or set SKIP_WORKER_VERIFY=true"
fi

kubectl -n "${K8S_NAMESPACE}" delete pod "${DEPLOY_POD}" --ignore-not-found=true --wait=false

log "Verifying from Worker pod: ${WORKER_POD}"

if ! kubectl -n "${K8S_NAMESPACE}" exec "${WORKER_POD}" -c "${WORKER_CONTAINER}" -- sh -lc "
set -eu
echo '[INFO] host='\"\$(hostname 2>/dev/null || uname -n)\"
test -d '${ETL_BASE}'
test -L '${ETL_BASE}/current' || test -d '${ETL_BASE}/current'
test -f '${ETL_BASE}/current/VERSION'
test -d '${ETL_BASE}/current/sql_scripts'
test -f '${ETL_BASE}/current/sql_scripts/load_env.sh'
test -f '${ETL_BASE}/current/sql_scripts/pdf_pipe/run_pdf_pipe_ds.py'
test -r '${DB_SECRET_MOUNT_PATH}/db.env'
. '${DB_SECRET_MOUNT_PATH}/db.env'
test -n \"\${MYSQL_HOST:-}\"
test -n \"\${MYSQL_PASSWORD:-}\"
echo '[OK] ETL_BASE=${ETL_BASE}'
echo '[OK] version=' \$(cat '${ETL_BASE}/current/VERSION')
echo '[OK] MYSQL_HOST='\"\${MYSQL_HOST}\"
echo '[OK] db.env readable'
"; then
  fail "Worker verification failed in pod ${WORKER_POD} (container ${WORKER_CONTAINER}). Check volumeMounts for ${ETL_BASE} and ${DB_SECRET_MOUNT_PATH}."
fi

log "Deploy finished successfully: ${GIT_SHA}"
