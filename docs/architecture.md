# Architecture

This tree is a public extract from a larger private KISTI research/assignment
codebase related to supercomputing acceleration for high-fidelity models and
large-scale virtual reactor simulation for SMR engineering analysis. The full
project cannot be published, so this directory isolates the CUDA C/C++ sparse
solver layer and the small Fortran/C callers needed to review it.

## Default Call Flow

```text
examples/fortran_csr/main.f90
  -> src/fortran/mod_kisti.f90
     - NVFORTRAN cudafor device arrays
     - bind(C) interface
  -> include/kisti_solver_c.h / src/cuda/kisti_solver_c.cu
     - public C ABI
     - solver dispatch
  -> src/cuda/solver3_diagbicg/kkh_cudiagbicg.cu
     - diagonal-preconditioned BiCGStab
  -> src/cuda/kkh_cudatools/kkh_cudatools.cu
     - cuSPARSE SpMV
     - custom CUDA vector/scalar kernels
```

## Shared ABI

```c
void kisti_solver_c(int n, int m,
                    int *d_rowPtr, int *d_colInd,
                    double *d_val, double *d_vec);
```

The pointer arguments are device pointers. Fortran reaches the ABI through `bind(C)` and NVFORTRAN `device` arrays. C reaches the same ABI by allocating/copying CUDA runtime device memory directly.

## Core Path

- `examples/fortran_csr/main.f90`: reads the small CSR input and calls `mod_kisti_switch`.
- `src/fortran/mod_kisti.f90`: copies host CSR arrays into NVFORTRAN device arrays and calls `kisti_solver_c`.
- `examples/c_csr/main.c`: allocates CUDA device memory and calls `kisti_solver_c` directly.
- `src/cuda/kisti_solver_c.cu`: selects the default diagonal solver unless optional macros are provided.
- `src/cuda/solver3_diagbicg/kkh_cudiagbicg.cu`: uses cuSPARSE SpMV, cuBLAS dot products, custom CUDA kernels, and NVTX ranges.

## Optional Paths

- `make ilu`: builds `KISTI_SOLVER_ILU`, which dispatches to `solver7_iLU`.
- `make amgx-install`: optional helper path that clones/builds AmgX into `.local/amgx`.
- `make amgx`: builds `KISTI_SOLVER_AMGX`, which dispatches to `solver6_AmgX_recycle`.
- `examples/cupid_gfortran_bridge`: keeps the CUPID/gfortran bridge source as integration evidence, but it is intentionally not part of the default `make test`.

## Build Boundary

The default `make` target builds only the shared CUDA solver and the two compact CSR callers. Optional AmgX and iLU evidence stays out of the default path so missing AmgX or solver-specific dependencies do not break the main public extract. AmgX source and local install artifacts are intentionally kept under ignored paths, `external/AMGX` and `.local/amgx`.
