#!/usr/bin/env bash
# 供 CI 脚本共用：shell runner 无 kubectl 时自动下载（带缓存与重试）

kubectl_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    *) echo "[ERROR] unsupported arch: $(uname -m)" >&2; return 1 ;;
  esac
}

ensure_kubectl() {
  local fail_fn arch ver bin_url dest tmp_dir cache_dir cached i
  log() { echo "[INFO] $*" >&2; }
  fail_fn() { echo "[ERROR] $*" >&2; return 1; }

  if [ -n "${KUBECTL_BIN:-}" ] && [ -x "${KUBECTL_BIN}" ]; then
    export PATH="$(dirname "${KUBECTL_BIN}"):${PATH}"
  fi

  if command -v kubectl >/dev/null 2>&1; then
    log "kubectl: $(command -v kubectl)"
    return 0
  fi

  for candidate in \
    "${KUBECTL_CACHE_PATH:-}" \
    /opt/gitlab-runner/cache/kubectl \
    /usr/local/bin/kubectl \
    /usr/bin/kubectl \
    /snap/bin/kubectl; do
    [ -n "${candidate}" ] || continue
    if [ -x "${candidate}" ]; then
      export PATH="$(dirname "${candidate}"):${PATH}"
      log "kubectl: ${candidate}"
      return 0
    fi
  done

  if [ "${AUTO_INSTALL_KUBECTL:-true}" != "true" ]; then
    fail_fn "kubectl not found; set KUBECTL_BIN or install on shell runner"
    return 1
  fi

  command -v curl >/dev/null 2>&1 || { fail_fn "kubectl not found and curl missing"; return 1; }

  tmp_dir="${ENSURE_KUBECTL_TMP_DIR:-${TMP_DIR:-}}"
  if [ -z "${tmp_dir}" ]; then
    tmp_dir="$(mktemp -d)"
    ENSURE_KUBECTL_TMP_DIR="${tmp_dir}"
  fi

  cache_dir="${KUBECTL_CACHE_DIR:-/opt/gitlab-runner/cache}"
  cached="${cache_dir}/kubectl"
  if [ -x "${cached}" ]; then
    export PATH="${cache_dir}:${PATH}"
    log "kubectl: ${cached} (cache)"
    return 0
  fi

  arch="$(kubectl_arch)" || return 1
  ver="${KUBECTL_VERSION:-v1.30.0}"
  if [ "${ver}" = "stable" ] || [ -z "${ver}" ]; then
    log "fetching kubectl stable version..."
    ver="$(curl -fsSL --max-time 60 https://dl.k8s.io/release/stable.txt 2>/dev/null || echo v1.30.0)"
  fi
  bin_url="https://dl.k8s.io/release/${ver}/bin/linux/${arch}/kubectl"
  dest="${tmp_dir}/kubectl"
  log "kubectl not on runner; downloading ${ver} (${arch})..."

  for i in 1 2 3; do
    if curl -fsSL --connect-timeout 30 --max-time 600 -C - "${bin_url}" -o "${dest}"; then
      break
    fi
    log "kubectl download retry ${i}/3..."
    [ "${i}" -eq 3 ] && { fail_fn "kubectl download failed: ${bin_url}"; return 1; }
    sleep 5
  done

  chmod +x "${dest}"
  if [ -d "${cache_dir}" ] && [ -w "${cache_dir}" ]; then
    cp "${dest}" "${cached}" && chmod +x "${cached}" && dest="${cached}"
    log "kubectl cached to ${cached}"
  fi
  export PATH="$(dirname "${dest}"):${PATH}"
  log "kubectl installed: ${dest}"
  kubectl version --client=true 2>/dev/null | head -1 >&2 || true
  return 0
}
