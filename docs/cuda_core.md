# CUDA Core

The repository is organized around `src`. That directory is the extracted CUDA
sparse solver layer; examples only prove how to call it.

## Common ABI

`src/kisti_solver_c.cu` exposes one C ABI:

```c
void kisti_solver_c(int n, int m,
                    int *d_rowPtr, int *d_colInd,
                    double *d_val, double *d_vec);
```

The pointers are CUDA device pointers. C callers allocate them directly with
the CUDA Runtime. Fortran callers reach the same ABI through `bind(C)` and
NVFORTRAN `device` arrays in `examples/fortran_common/mod_kisti.f90`.

Compile-time macros select the solver path:

```text
default             -> solver3_diagbicg
KISTI_SOLVER_ILU    -> solver7_iLU
KISTI_SOLVER_AMGX   -> solver6_AmgX_recycle
```

## Diagonal BiCGStab

Files:

- `src/solver3_diagbicg/kkh_cudiagbicg.cu`
- `src/kkh_cudatools/kkh_cudatools.cu`

Flow:

```text
CSR A, vector b on GPU
-> extract invdiag(A) with a CUDA kernel
-> apply y = invdiag(A) * p
-> compute A*y with cuSPARSE SpMV
-> compute Krylov dot products with cuBLAS Ddot
-> update vectors with custom CUDA kernels
```

This is the default no-extra-dependency path.

## iLU(0) + cuSPARSE SpSV BiCGStab

Files:

- `src/solver7_iLU/kkh_cuiLUbicg.cu`
- `src/kkh_cudatools/kkh_iLU_cpu.cu`
- `src/kkh_cudatools/kkh_cudatools.cu`

Flow:

```text
CSR A on GPU
-> copy CSR to host
-> compute iLU(0) factors L and U
-> upload L/U CSR factors to GPU
-> apply preconditioner with cuSPARSE SpSV:
   L * tmp = p
   U * y   = tmp
-> continue BiCGStab with cuSPARSE SpMV and cuBLAS Ddot
```

This path is core evidence for triangular-solve based preconditioning.

## AmgX AMG/GMRES

Files:

- `src/solver5_AmgX/kkh_cuAmgX.cu`
- `src/solver6_AmgX_recycle/kkh_cuAmgX.cu`
- `examples/amgx_config/amgx_config.json`

Flow:

```text
CSR A and vector b on GPU
-> create AmgX config/resources/matrix/vector handles
-> upload matrix and RHS through AmgX C API
-> setup AMG/Krylov solver
-> solve and download result into the device vector
-> for recycle path, replace coefficients and reuse solver state
```

AmgX is a core solver path in this repository. It is not built by default only
because it needs an external AmgX installation.

## Shared Helper Layer

`src/kkh_cudatools` contains the reusable CUDA helper layer:

- CUDA Runtime allocation/copy helpers.
- cuSPARSE CSR SpMV setup and solve wrappers.
- cuSPARSE SpSV setup, analysis, and triangular solve wrappers.
- Custom vector and scalar kernels used in the Krylov loops.
- NVTX ranges for Nsight profiling.
