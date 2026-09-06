# DS Worker 扩展镜像：在 Worker 基础镜像上安装 requirements.txt
#
# BASE_IMAGE 由 build.sh / CI 传入

ARG BASE_IMAGE
FROM ${BASE_IMAGE}

USER root

# Ubuntu 24.04+ (PEP 668)：容器内允许 pip 装包
ENV PIP_BREAK_SYSTEM_PACKAGES=1

COPY requirements.txt /tmp/ds-worker-requirements.txt

RUN set -eux; \
    if ! python3 -m pip --version >/dev/null 2>&1; then \
      apt-get update; \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        python3-pip ca-certificates; \
      rm -rf /var/lib/apt/lists/*; \
    fi; \
    python3 -m pip install --no-cache-dir -r /tmp/ds-worker-requirements.txt; \
    rm -f /tmp/ds-worker-requirements.txt; \
    python3 -c "import pymysql; print('pymysql OK', pymysql.__version__)"
