#!/usr/bin/env bash
set -euo pipefail

AMGX_SRC_DIR="${AMGX_SRC_DIR:-external/AMGX}"

if [ -d "${AMGX_SRC_DIR}/.git" ]; then
    echo "[amgx] Updating existing source tree: ${AMGX_SRC_DIR}"
    git -C "${AMGX_SRC_DIR}" fetch --tags
    git -C "${AMGX_SRC_DIR}" pull --ff-only
else
    echo "[amgx] Cloning NVIDIA/AMGX into: ${AMGX_SRC_DIR}"
    mkdir -p "$(dirname "${AMGX_SRC_DIR}")"
    git clone https://github.com/NVIDIA/AMGX.git "${AMGX_SRC_DIR}"
fi

