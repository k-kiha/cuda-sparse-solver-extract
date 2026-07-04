# CUDA Library Usage Reference

이 문서는 README의 CUDA library matrix와 코드 안의 `[library]` 태그가 서로 맞는지 검토하기 위한 참조 문서입니다.

## cuSPARSE CSR SpMV

- 용도: BiCGStab 반복에서 `A*x`를 계산합니다.
- API: `cusparseCreate`, `cusparseCreateCsr`, `cusparseCreateDnVec`, `cusparseSpMV_bufferSize`, `cusparseSpMV`.
- 소스:
  - `src/cuda/kkh_cudatools/kkh_cudatools.cu`: `kkh_cuspmv_init`, `kkh_cuspmv`.
  - `src/cuda/solver3_diagbicg/kkh_cudiagbicg.cu`: 기본 solver의 SpMV 호출.
  - `src/cuda/solver7_iLU/kkh_cuiLUbicg.cu`: iLU 전처리 solver의 SpMV 호출.
- 관련 예제: `examples/fortran_csr`, `examples/c_csr`.

## cuBLAS

- 용도: Krylov 반복의 dot product를 device pointer mode로 계산합니다.
- API: `cublasCreate`, `cublasSetPointerMode`, `cublasDdot`, `cublasDestroy`.
- 소스:
  - `src/cuda/solver3_diagbicg/kkh_cudiagbicg.cu`: residual norm, `rho`, `omega` 계산.
  - `src/cuda/solver7_iLU/kkh_cuiLUbicg.cu`: iLU 전처리 BiCGStab의 동일 inner product 계산.
- 관련 예제: 기본 solver, optional iLU.

## cuSPARSE SpSV + iLU(0)

- 용도: CPU에서 만든 iLU(0) L/U CSR 행렬을 GPU로 올리고, lower/upper triangular solve를 전처리로 사용합니다.
- API: `cusparseSpMatSetAttribute`, `cusparseSpSV_createDescr`, `cusparseSpSV_bufferSize`, `cusparseSpSV_analysis`, `cusparseSpSV_solve`.
- 소스:
  - `src/cuda/kkh_cudatools/kkh_iLU_cpu.cu`: device CSR download, CPU iLU(0), L/U CSR upload.
  - `src/cuda/kkh_cudatools/kkh_cudatools.cu`: `kkh_cuspsv_init`, `kkh_cuspsv`, `kkh_cuspsv_init2`.
  - `src/cuda/solver7_iLU/kkh_cuiLUbicg.cu`: L solve 후 U solve를 Krylov preconditioner로 호출.
- 관련 예제: `examples/ilu_spSV_optional`.
- 정직한 해석: iteration 수를 줄일 수 있지만, triangular solve는 병렬성이 낮아 GPU headline path로는 항상 유리하지 않을 수 있습니다.

## AmgX

- 용도: NVIDIA AmgX를 이용해 AMG/GMRES setup, solve, coefficient replacement/reuse 흐름을 보여줍니다.
- API: `AMGX_initialize`, `AMGX_config_create_from_file`, `AMGX_resources_create_simple`, `AMGX_matrix_upload_all`, `AMGX_solver_setup`, `AMGX_solver_solve`, `AMGX_matrix_replace_coefficients`, `AMGX_vector_download`.
- 소스:
  - `src/cuda/solver5_AmgX/kkh_cuAmgX.cu`: one-shot matrix upload, setup, solve, download.
  - `src/cuda/solver6_AmgX_recycle/kkh_cuAmgX.cu`: matrix coefficient replacement 후 setup/solve, 이어서 solver reuse solve.
- 관련 예제: `examples/amgx_optional`.
- 설치/빌드: AmgX는 기본 의존성이 아니며, 나중에 `make amgx-install`로 `external/AMGX` 소스를 받아 `.local/amgx`에 repo-local 설치할 수 있게 준비했습니다.
- tradeoff:
  - setup 포함: AmgX hierarchy/resource 준비 비용까지 포함한 전체 solve 비용입니다.
  - coefficient reuse: matrix sparsity pattern이 유지될 때 coefficient 교체와 solver reuse 가능성을 보여줍니다.
  - per-solve reuse: setup을 재사용할 수 있는 반복 pressure solve에서는 매우 유리할 수 있지만, 재사용 가능성은 문제 흐름과 matrix 변화 방식에 의존합니다.

## CUDA Runtime, Custom Kernels, NVTX

- 용도: device memory 관리, host/device/device-to-device 복사, vector update kernel, scalar kernel, Nsight Systems/Compute 구간 라벨을 보여줍니다.
- API/기능: `cudaMalloc`, `cudaMallocHost`, `cudaMemcpy`, `cudaMemset`, `cudaFree`, `cudaDeviceSynchronize`, `__global__` kernels, `nvtxRangePushA`, `nvtxRangePop`.
- 소스:
  - `src/cuda/kisti_solver_c.cu`: shared-library ABI boundary synchronization.
  - `src/cuda/kkh_cudatools/kkh_cudatools.cu`: vector/scalar kernels와 SpMV/SpSV helper.
  - `src/cuda/solver3_diagbicg/kkh_cudiagbicg.cu`: NVTX 구간 `precond`, `Mmul`, `innerp`, `proj`.
  - `src/cuda/solver7_iLU/kkh_cuiLUbicg.cu`: iLU preconditioner와 Krylov loop profiling.

## Interoperability

- Fortran -> CUDA: `src/fortran/mod_kisti.f90`의 `bind(C)` 인터페이스가 NVFORTRAN `device` 배열을 `kisti_solver_c`에 넘깁니다.
- C -> CUDA: `examples/c_csr/main.c`가 `include/kisti_solver_c.h`를 포함하고 같은 ABI를 직접 호출합니다.
- 공통 ABI: `void kisti_solver_c(int n, int m, int *d_rowPtr, int *d_colInd, double *d_val, double *d_vec)`는 CSR row pointer, column index, value, RHS/solution vector가 모두 device pointer라고 가정합니다.
