#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

export AMGX_DIR="${AMGX_DIR:-${REPO_ROOT}/.local/amgx}"
export LD_LIBRARY_PATH="${AMGX_DIR}/lib:${LD_LIBRARY_PATH:-}"

echo "AMGX_DIR=${AMGX_DIR}"
echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"
