#!/usr/bin/env bash
set -euo pipefail

AMGX_SRC_DIR="${AMGX_SRC_DIR:-amgx_local/source}"
AMGX_GIT_URL="${AMGX_GIT_URL:-https://github.com/NVIDIA/AMGX.git}"
AMGX_GIT_REF="${AMGX_GIT_REF:-main}"

if [ -d "${AMGX_SRC_DIR}/.git" ]; then
    echo "[amgx] Updating existing source tree: ${AMGX_SRC_DIR}"
    git -C "${AMGX_SRC_DIR}" remote set-url origin "${AMGX_GIT_URL}"
    git -C "${AMGX_SRC_DIR}" fetch --tags origin
else
    echo "[amgx] Cloning NVIDIA/AMGX into: ${AMGX_SRC_DIR}"
    mkdir -p "$(dirname "${AMGX_SRC_DIR}")"
    git clone "${AMGX_GIT_URL}" "${AMGX_SRC_DIR}"
    git -C "${AMGX_SRC_DIR}" fetch --tags origin
fi

if [ -n "${AMGX_GIT_REF}" ]; then
    echo "[amgx] Checking out ref: ${AMGX_GIT_REF}"
    if git -C "${AMGX_SRC_DIR}" rev-parse --verify --quiet "origin/${AMGX_GIT_REF}^{commit}" >/dev/null; then
        git -C "${AMGX_SRC_DIR}" checkout -B "${AMGX_GIT_REF}" "origin/${AMGX_GIT_REF}"
    else
        git -C "${AMGX_SRC_DIR}" checkout "${AMGX_GIT_REF}"
    fi
fi

git -C "${AMGX_SRC_DIR}" submodule update --init --recursive

echo "[amgx] Source ready at ${AMGX_SRC_DIR}"
git -C "${AMGX_SRC_DIR}" --no-pager log -1 --oneline
