#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

export AMGX_GIT_URL="${AMGX_GIT_URL:-https://github.com/NVIDIA/AMGX.git}"
export AMGX_GIT_REF="${AMGX_GIT_REF:-main}"
export AMGX_SRC_DIR="${AMGX_SRC_DIR:-${REPO_ROOT}/amgx_local/source}"
export AMGX_BUILD_DIR="${AMGX_BUILD_DIR:-${REPO_ROOT}/amgx_local/build}"
export AMGX_INSTALL_DIR="${AMGX_INSTALL_DIR:-${REPO_ROOT}/amgx_local/install}"
export AMGX_CUDA_ARCH="${AMGX_CUDA_ARCH:-80}"
export AMGX_NO_MPI="${AMGX_NO_MPI:-ON}"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "[amgx] missing required command: $1" >&2
        exit 1
    fi
}

require_command git
require_command cmake

echo "[amgx] Preparing repo-local AmgX"
echo "[amgx] Repo   : ${REPO_ROOT}"
echo "[amgx] Git    : ${AMGX_GIT_URL}"
echo "[amgx] Ref    : ${AMGX_GIT_REF}"
echo "[amgx] Source : ${AMGX_SRC_DIR}"
echo "[amgx] Build  : ${AMGX_BUILD_DIR}"
echo "[amgx] Prefix : ${AMGX_INSTALL_DIR}"
echo "[amgx] Arch   : ${AMGX_CUDA_ARCH}"
echo "[amgx] MPI    : ${AMGX_NO_MPI}"

cd "${REPO_ROOT}"
"${SCRIPT_DIR}/fetch_amgx.sh"
"${SCRIPT_DIR}/build_amgx.sh"

if [ ! -f "${AMGX_INSTALL_DIR}/lib/libamgxsh.so" ]; then
    echo "[amgx] missing installed library: ${AMGX_INSTALL_DIR}/lib/libamgxsh.so" >&2
    exit 1
fi

cat <<MSG
[amgx] Ready.
[amgx] Next commands:
    source src/amgx_setup/env_amgx.sh
    make core-amgx
    make examples-amgx
    make run-amgx-c
    make run-amgx-fortran
MSG
