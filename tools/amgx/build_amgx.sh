#!/usr/bin/env bash
set -euo pipefail

AMGX_SRC_DIR="${AMGX_SRC_DIR:-external/AMGX}"
AMGX_BUILD_DIR="${AMGX_BUILD_DIR:-${AMGX_SRC_DIR}/build}"
AMGX_INSTALL_DIR="${AMGX_INSTALL_DIR:-.local/amgx}"
AMGX_CUDA_ARCH="${AMGX_CUDA_ARCH:-80}"
AMGX_NO_MPI="${AMGX_NO_MPI:-ON}"
CC_COMPILER="${CC:-gcc}"
CXX_COMPILER="${CXX:-g++}"

if [ ! -d "${AMGX_SRC_DIR}" ]; then
    echo "[amgx] Missing AMGX source tree: ${AMGX_SRC_DIR}" >&2
    echo "[amgx] Run tools/amgx/fetch_amgx.sh first." >&2
    exit 1
fi

echo "[amgx] Source : ${AMGX_SRC_DIR}"
echo "[amgx] Build  : ${AMGX_BUILD_DIR}"
echo "[amgx] Prefix : ${AMGX_INSTALL_DIR}"
echo "[amgx] Arch   : ${AMGX_CUDA_ARCH}"

cmake -S "${AMGX_SRC_DIR}" -B "${AMGX_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="${CC_COMPILER}" \
    -DCMAKE_CXX_COMPILER="${CXX_COMPILER}" \
    -DCUDA_ARCH="${AMGX_CUDA_ARCH}" \
    -DCMAKE_NO_MPI="${AMGX_NO_MPI}"

cmake --build "${AMGX_BUILD_DIR}" --parallel

mkdir -p "${AMGX_INSTALL_DIR}/include" "${AMGX_INSTALL_DIR}/lib"
cp -R "${AMGX_SRC_DIR}/include/." "${AMGX_INSTALL_DIR}/include/"
find "${AMGX_BUILD_DIR}" -type f \( -name 'libamgx*.so' -o -name 'libamgx*.a' \) -exec cp {} "${AMGX_INSTALL_DIR}/lib/" \;

if [ ! -f "${AMGX_INSTALL_DIR}/lib/libamgxsh.so" ]; then
    echo "[amgx] Built library was not found at ${AMGX_INSTALL_DIR}/lib/libamgxsh.so" >&2
    echo "[amgx] Check the build output under ${AMGX_BUILD_DIR}." >&2
    exit 1
fi

echo "[amgx] Installed repo-local AmgX under ${AMGX_INSTALL_DIR}"

