#!/usr/bin/env bash

if [ -n "${BASH_SOURCE:-}" ]; then
    AMGX_ENV_SCRIPT="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
    AMGX_ENV_SCRIPT="${(%):-%x}"
else
    AMGX_ENV_SCRIPT="$0"
fi

SCRIPT_DIR="$(cd "$(dirname "${AMGX_ENV_SCRIPT}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_MK="${REPO_ROOT}/config.mk"
CONFIG_AMGX_DIR=""

if [ -z "${AMGX_DIR:-}" ] && [ -f "${CONFIG_MK}" ]; then
    CONFIG_AMGX_DIR="$(
        awk '
            /^[[:space:]]*AMGX_DIR[[:space:]]*[:?+]?=/ {
                sub(/^[^=]*=/, "")
                gsub(/^[ \t]+|[ \t]+$/, "")
                print
                exit
            }
        ' "${CONFIG_MK}"
    )"
    CONFIG_AMGX_DIR="$(printf '%s\n' "${CONFIG_AMGX_DIR}" | sed "s|\$(CURDIR)|${REPO_ROOT}|g")"
    CONFIG_AMGX_DIR="$(printf '%s\n' "${CONFIG_AMGX_DIR}" | sed "s|\${CURDIR}|${REPO_ROOT}|g")"
fi

export AMGX_DIR="${AMGX_DIR:-${CONFIG_AMGX_DIR:-${REPO_ROOT}/amgx_local/install}}"
export LD_LIBRARY_PATH="${AMGX_DIR}/lib:${LD_LIBRARY_PATH:-}"

echo "AMGX_DIR=${AMGX_DIR}"
echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"

unset AMGX_ENV_SCRIPT
unset CONFIG_MK
unset CONFIG_AMGX_DIR
