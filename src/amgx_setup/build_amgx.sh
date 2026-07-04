#!/usr/bin/env bash
set -euo pipefail

AMGX_SRC_DIR="${AMGX_SRC_DIR:-amgx_local/source}"
AMGX_BUILD_DIR="${AMGX_BUILD_DIR:-amgx_local/build}"
AMGX_INSTALL_DIR="${AMGX_INSTALL_DIR:-amgx_local/install}"
AMGX_CUDA_ARCH="${AMGX_CUDA_ARCH:-80}"
AMGX_NO_MPI="${AMGX_NO_MPI:-ON}"
AMGX_BUILD_JOBS="${AMGX_BUILD_JOBS:-}"
CC_COMPILER="${CC:-gcc}"
CXX_COMPILER="${CXX:-g++}"

if [ ! -d "${AMGX_SRC_DIR}" ]; then
    echo "[amgx] Missing AMGX source tree: ${AMGX_SRC_DIR}" >&2
    echo "[amgx] Run src/amgx_setup/fetch_amgx.sh first." >&2
    exit 1
fi

echo "[amgx] Source : ${AMGX_SRC_DIR}"
echo "[amgx] Build  : ${AMGX_BUILD_DIR}"
echo "[amgx] Prefix : ${AMGX_INSTALL_DIR}"
echo "[amgx] Arch   : ${AMGX_CUDA_ARCH}"

cmake_args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_C_COMPILER="${CC_COMPILER}"
    -DCMAKE_CXX_COMPILER="${CXX_COMPILER}"
    -DCUDA_ARCH="${AMGX_CUDA_ARCH}"
    -DCMAKE_NO_MPI="${AMGX_NO_MPI}"
)

if [ -n "${CUDA_HOME:-}" ]; then
    cmake_args+=("-DCUDAToolkit_ROOT=${CUDA_HOME}")
fi

cmake -S "${AMGX_SRC_DIR}" -B "${AMGX_BUILD_DIR}" \
    "${cmake_args[@]}"

if [ -n "${AMGX_BUILD_JOBS}" ]; then
    cmake --build "${AMGX_BUILD_DIR}" --parallel "${AMGX_BUILD_JOBS}"
else
    cmake --build "${AMGX_BUILD_DIR}" --parallel
fi

mkdir -p "${AMGX_INSTALL_DIR}/include" "${AMGX_INSTALL_DIR}/lib"
cp -R "${AMGX_SRC_DIR}/include/." "${AMGX_INSTALL_DIR}/include/"
find "${AMGX_BUILD_DIR}" -type f \( -name 'libamgx*.so' -o -name 'libamgx*.a' \) -exec cp {} "${AMGX_INSTALL_DIR}/lib/" \;

if [ ! -f "${AMGX_INSTALL_DIR}/lib/libamgxsh.so" ]; then
    echo "[amgx] Built library was not found at ${AMGX_INSTALL_DIR}/lib/libamgxsh.so" >&2
    echo "[amgx] Check the build output under ${AMGX_BUILD_DIR}." >&2
    exit 1
fi

echo "[amgx] Installed repo-local AmgX under ${AMGX_INSTALL_DIR}"
