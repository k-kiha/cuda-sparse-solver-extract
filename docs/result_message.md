# Performance Framing

현재 `_cleanup` 트리에서 새로 재현한 성능 측정값은 없습니다. 따라서 공개 README나 과제 코드 공개 추출본 설명에서는 이 디렉터리의 코드를 직접 빌드/실행해 얻은 값만 성능 수치로 주장해야 합니다.

## What Can Be Claimed Now

- 이 트리는 KISTI 고정밀 모델 슈퍼컴퓨팅 가속 및 SMR 가상 원자로 시뮬레이션 가속 과제 맥락에서 분리한 CUDA C/C++ sparse solver 계층과 Fortran/C 공통 ABI 호출 구조를 보여줍니다.
- diagonal BiCGStab 경로는 cuSPARSE CSR SpMV, cuBLAS dot product, CUDA custom kernels, NVTX ranges를 포함합니다.
- iLU 경로는 CPU iLU(0) factorization과 GPU cuSPARSE SpSV triangular solve를 보여줍니다.
- AmgX 경로는 setup, solve, coefficient replacement/reuse 흐름을 보여줍니다. AmgX 설치/링크가 필요할 뿐, 이 repo의 core solver path 중 하나입니다.

## What Is Not Claimed Yet

- 이 `_cleanup` 트리에서 `make run`으로 새로 얻은 wall-clock speedup은 아직 없습니다.
- H100, GH200, H200 등 특정 GPU에서의 speedup, bandwidth, occupancy 수치는 아직 주장하지 않습니다.
- 기존 그림 또는 가상 보고서의 수치는 재측정 전까지 공개 성능 claim으로 쓰지 않습니다.

## Reproducible Measurement Template

성능 수치를 공개하려면 아래 정보를 함께 남겨 주세요.

```text
hardware:
  CPU:
  GPU:
  driver/CUDA:
  compiler:
input:
  matrix:
  n:
  nnz:
command:
  build:
  run:
metrics:
  H2D:
  solver:
  D2H:
  total:
  iterations:
profiling:
  NVTX ranges:
  Nsight command:
```

## Suggested Measurement Story

1. `make run`으로 작은 CSR 입력이 양쪽 caller에서 정상 실행되는지 확인합니다.
2. 큰 pressure matrix 입력을 별도 benchmark 데이터로 고정합니다.
3. 기본 diagonal BiCGStab에서 NVTX `precond`, `Mmul`, `innerp`, `proj` 구간을 분리해 측정합니다.
4. iLU는 SpSV 구간이 전체 solver 시간을 얼마나 차지하는지 확인합니다.
5. AmgX는 setup 포함 solve와 coefficient reuse solve를 분리해 기록합니다.

## Historical Context

루트의 `4_260703_virtual_cuda_solver_result_report.md`에는 첨부 그림과 `scahpcasia_abstract.pdf`를 바탕으로 만든 가상 결과 메시지가 보존되어 있습니다. 그 문서는 성능 스토리 초안이며, 현재 `_cleanup` 코드에서 재측정한 결과가 아닙니다.
