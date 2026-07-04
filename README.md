# Project-Derived CUDA C++ Sparse Solver Extract

이 저장소는 KISTI의 고정밀 모델 슈퍼컴퓨팅 가속 연구, 특히 SMR 공학 해석을 위한 대규모 가상 원자로 시뮬레이션 가속 과제 맥락에서 나온 CUDA C/C++ CSR sparse solver 공개 추출본입니다. 전체 과제 코드는 공개할 수 없기 때문에, Fortran/C ABI, CUDA Runtime, custom kernels, cuSPARSE, cuBLAS, cuSPARSE SpSV+iLU(0), AmgX 사용 지점을 검토 가능한 범위로 분리해 정리했습니다.

## CUDA Library Matrix

| 라이브러리 | 용도 | 핵심 소스 경로 | 관련 예제 |
|---|---|---|---|
| cuSPARSE CSR SpMV | BiCGStab의 `A*x` 행렬-벡터 곱 | [`src/cuda/kkh_cudatools/kkh_cudatools.cu`](src/cuda/kkh_cudatools/kkh_cudatools.cu), [`src/cuda/solver3_diagbicg/kkh_cudiagbicg.cu`](src/cuda/solver3_diagbicg/kkh_cudiagbicg.cu) | [`examples/fortran_csr`](examples/fortran_csr), [`examples/c_csr`](examples/c_csr) |
| cuBLAS dot/vector scalar ops | Krylov inner product와 device scalar 갱신 | [`src/cuda/solver3_diagbicg/kkh_cudiagbicg.cu`](src/cuda/solver3_diagbicg/kkh_cudiagbicg.cu), [`src/cuda/solver7_iLU/kkh_cuiLUbicg.cu`](src/cuda/solver7_iLU/kkh_cuiLUbicg.cu) | 기본 solver, optional iLU |
| cuSPARSE SpSV + iLU(0) | L/U triangular solve 기반 전처리 실험 | [`src/cuda/solver7_iLU/kkh_cuiLUbicg.cu`](src/cuda/solver7_iLU/kkh_cuiLUbicg.cu), [`src/cuda/kkh_cudatools/kkh_iLU_cpu.cu`](src/cuda/kkh_cudatools/kkh_iLU_cpu.cu) | [`examples/ilu_spSV_optional`](examples/ilu_spSV_optional) |
| AmgX | AMG/GMRES setup, solve, coefficient reuse 비교 | [`src/cuda/solver5_AmgX/kkh_cuAmgX.cu`](src/cuda/solver5_AmgX/kkh_cuAmgX.cu), [`src/cuda/solver6_AmgX_recycle/kkh_cuAmgX.cu`](src/cuda/solver6_AmgX_recycle/kkh_cuAmgX.cu) | [`examples/amgx_optional`](examples/amgx_optional) |
| CUDA Runtime + NVTX | device allocation/copy, custom kernels, Nsight 구간 라벨 | [`src/cuda/kkh_cudatools/kkh_cudatools.cu`](src/cuda/kkh_cudatools/kkh_cudatools.cu), [`src/cuda/kisti_solver_c.cu`](src/cuda/kisti_solver_c.cu) | 기본 solver |

자세한 호출 API와 코드 태그는 [`docs/cuda_library_usage.md`](docs/cuda_library_usage.md)에 정리했습니다.

## Tree

```text
include/                     Fortran/C가 공유하는 public C ABI
src/fortran/                 NVFORTRAN cudafor device array + bind(C) 연결
src/cuda/kisti_solver_c.cu   공통 ABI entrypoint와 solver dispatch
src/cuda/kkh_cudatools/      CUDA runtime, cuSPARSE SpMV/SpSV, custom kernels
src/cuda/solver3_diagbicg/   기본 대각 전처리 BiCGStab
src/cuda/solver7_iLU/        optional iLU(0) + cuSPARSE SpSV
src/cuda/solver5_AmgX/       optional AmgX one-shot setup/solve
src/cuda/solver6_AmgX_recycle/ optional AmgX coefficient reuse
examples/fortran_csr/        Fortran caller, NVFORTRAN device array path
examples/c_csr/              C caller, 동일 ABI 직접 호출
examples/cupid_gfortran_bridge/ CUPID/gfortran bridge evidence source
data/small_csr/              make test용 작은 CSR 입력
docs/                        아키텍처, 라이브러리 사용, 성능 프레이밍
tools/amgx/                  optional AmgX repo-local install helpers
external/                    optional external source checkout area
```

## Default Evidence Path

```text
examples/fortran_csr/main.f90
  -> src/fortran/mod_kisti.f90
  -> include/kisti_solver_c.h / src/cuda/kisti_solver_c.cu
  -> src/cuda/solver3_diagbicg/kkh_cudiagbicg.cu
  -> src/cuda/kkh_cudatools/kkh_cudatools.cu
```

이 기본 경로는 Fortran의 `bind(C)` 인터페이스와 NVFORTRAN device array를 통해 이미 GPU에 올라간 CSR 배열을 `kisti_solver_c` ABI로 넘깁니다. C 예제는 같은 ABI를 직접 호출하므로, Fortran wrapper 없이도 동일 CUDA solver shared library를 사용할 수 있음을 보여줍니다.

## Build And Test

```bash
cp config.mk.example config.mk
# config.mk에서 CUDA_HOME, 컴파일러, 필요 시 AMGX_DIR을 현재 환경에 맞게 수정합니다.
make
make test
```

사전 점검은 `make env-check`로 실행합니다. 이 로컬 세션에서는 NVHPC/CUDA 경로가 확인되지 않았으므로 실제 컴파일 성공을 단정하지 않습니다.

Optional evidence:

```bash
make ilu
make amgx-install   # optional: clone/build AmgX into .local/amgx
make amgx
make cupid-bridge
```

By default, AmgX is not required for `make` or `make test`. The optional
repo-local AmgX path is prepared for later use:

```bash
make amgx-install
source tools/amgx/env_amgx.sh
make amgx
```

This keeps the public extract lightweight while preserving a path to build and
test the AmgX integration in a reproducible local prefix.

## Performance Framing

현재 `_cleanup` 트리에서 새로 측정한 성능 수치는 아직 없습니다. 공개 주장에는 `make test` 또는 별도 benchmark 입력, 하드웨어, 명령, Nsight/NVTX 구간을 함께 기록한 재현 가능한 값만 사용해 주세요. 기존 그림 기반 성능 이야기는 [`docs/result_message.md`](docs/result_message.md)에 “미측정/재측정 필요”로 분리했습니다.
