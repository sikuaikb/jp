#!/usr/bin/env bash
# 生成 GitLab CI 变量 KUBECONFIG_B64 用的单行 base64
set -euo pipefail

SRC="${1:-${HOME}/.kube/config}"
if [ ! -f "${SRC}" ]; then
  echo "kubeconfig not found: ${SRC}" >&2
  exit 1
fi

echo "[INFO] encoding: ${SRC}" >&2
base64 -w0 "${SRC}"
echo
