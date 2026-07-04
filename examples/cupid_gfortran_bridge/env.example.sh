module purge
# ===== 사용자 입력(필요한 것만) =====
module load gcc/10.2.0
module load mpi/openmpi-4.1.8
module load cuda/12.3
module load nvidia_hpc_sdk/24.1

export CUDA_HOME="${CUDA_HOME:-/path/to/cuda}"
export CUDA_LIB_PATH="${CUDA_LIB_PATH:-${CUDA_HOME}/lib64}"
echo "[env] CUDA_LIB_PATH  = ${CUDA_LIB_PATH}"

now=$(pwd)
