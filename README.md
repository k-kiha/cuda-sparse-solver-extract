# CUDA Sparse Solver Extract

This repository is a public extract of the CUDA C/C++ sparse solver layer from
a larger KISTI SMR virtual reactor acceleration codebase. The core
implementation and CUPID/gfortran bridge source are under `src`. Runnable
callers, small CSR input data, documentation, and generated dependency outputs
are kept outside the core layer.

## Core Solver Paths

`src` contains three project-derived CUDA sparse solver paths:

| Path | Role | CUDA libraries |
|---|---|---|
| `src/solver3_diagbicg` | Diagonal-preconditioned BiCGStab | cuSPARSE SpMV, cuBLAS, CUDA kernels |
| `src/solver7_iLU` | iLU(0)-preconditioned BiCGStab | cuSPARSE SpMV, cuSPARSE SpSV, cuBLAS |
| `src/solver5_AmgX`, `src/solver6_AmgX_recycle` | AmgX AMG/GMRES setup, solve, coefficient reuse | AmgX C API, CUDA device pointers |

The common ABI is implemented in `src/kisti_solver_c.cu`:

```c
void kisti_solver_c(int n, int m,
                    int *d_rowPtr, int *d_colInd,
                    double *d_val, double *d_vec);
```

All pointer arguments are CUDA device pointers.

## Layout

```text
src/                         Core CUDA sparse solver implementation
src/include/                 Public C ABI header
src/amgx_setup/              Scripts that prepare the external AmgX dependency
src/cupid_gfortran_bridge/   CUPID-like gfortran app to NVHPC/CUDA bridge
examples/diag_c/             C caller for diagonal BiCGStab
examples/diag_fortran/       Fortran caller for diagonal BiCGStab
examples/ilu_c/              C caller for iLU(0)+SpSV BiCGStab
examples/ilu_fortran/        Fortran caller for iLU(0)+SpSV BiCGStab
examples/amgx_c/             C caller for the AmgX core path
examples/amgx_fortran/       Fortran caller for the AmgX core path
examples/amgx_config/        AmgX JSON configuration used at runtime
examples/_common/fortran/    Shared Fortran bind(C) adapter for examples
examples/data/small_csr/     Small CSR Ax=b input shared by all examples
docs/                        Focused notes for the CUDA core and runs
```

`src` is the part to read first when judging the CUDA sparse solver work.
`examples` shows how to call that layer. `src/cupid_gfortran_bridge` is kept
inside `src` because it is source-level evidence for connecting the extracted
CUDA solver layer to the original CUPID-like gfortran application.

## Build

```bash
cp config.mk.example config.mk
# Edit CUDA_HOME and, for AmgX, AMGX_DIR if needed.
make env-check
```

Build only the core no-AmgX libraries:

```bash
make core
```

Build only the no-AmgX example executables after the libraries are available:

```bash
make examples
```

CUDA 12+ usually provides NVTX through headers, so this repo does not link
`-lnvToolsExt` by default. Older CUDA environments can opt in from `config.mk`:

```make
NVTX_LIBS ?= -lnvToolsExt
```

## Run Without AmgX

This runs the diagonal and iLU core solver paths on the small CSR input.

```bash
make clean
make run
```

Equivalent explicit targets:

```bash
make run-diag-c
make run-diag-fortran
make run-ilu-c
make run-ilu-fortran
```

Successful runs create result files under `build/run/*/`.

## Run With AmgX

AmgX is a core solver path in this extract, but it requires the external AmgX
library. Put `CUDA_HOME` and AmgX options in `config.mk`, then install the
repo-local AmgX dependency through Make. The recommended full flow is:

```bash
make amgx-install
source src/amgx_setup/env_amgx.sh
make src-all
make examples-all
make run-all
```

`source src/amgx_setup/env_amgx.sh` also reads `AMGX_DIR` from `config.mk`
when present, so custom AmgX install paths stay consistent.

If AmgX is already installed outside this repository, set `AMGX_DIR` in
`config.mk` to that install prefix, skip `make amgx-install`, then run:

```bash
source src/amgx_setup/env_amgx.sh
make src-all
make examples-all
make run-all
```

`make test` and `make test-all` remain compatibility aliases for `make run`
and `make run-all`.

The prepare script creates `amgx_local/` for downloaded AmgX source, build
files, and the local install prefix. That directory is ignored by git.

## Documentation

- `docs/cuda_core.md`: what each `src` solver path does.
- `docs/build_and_run.md`: command-oriented build and run guide.
- `docs/result_message.md`: performance-claim boundary and measurement template.
