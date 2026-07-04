# Build And Run

## Configure

```bash
cp config.mk.example config.mk
```

Set at least:

```make
CUDA_HOME ?= /path/to/cuda
CUDA_INC_PATH ?= $(CUDA_HOME)/include
CUDA_LIB_PATH ?= $(CUDA_HOME)/lib64
```

On A100, adding `-gpu=cc80` to `CUDA_CXXFLAGS` and `FORTRAN_FLAGS` is
reasonable for NVHPC builds.

Check the environment:

```bash
make env-check
```

## Build Layers

Build the extracted CUDA sparse solver libraries under `src`:

```bash
make core
```

Build the no-AmgX example executables that call those libraries:

```bash
make examples
```

Build the AmgX library and examples after AmgX is installed:

```bash
make core-amgx
make examples-amgx
```

## No-AmgX Core Paths

These commands build and run the diagonal and iLU solver paths with the same
small CSR input.

```bash
make clean
make run
```

Individual targets:

```bash
make run-diag-c
make run-diag-fortran
make run-ilu-c
make run-ilu-fortran
```

Outputs:

```text
build/run/diag_c/result_c.txt
build/run/diag_fortran/result.txt
build/run/ilu_c/result_c.txt
build/run/ilu_fortran/result.txt
```

## AmgX Core Path

Use an existing AmgX install:

```make
AMGX_DIR ?= /path/to/amgx
```

Or install into the repo-local prefix using the values from `config.mk`:

```bash
make amgx-install
source src/amgx_setup/env_amgx.sh
```

`env_amgx.sh` reads `AMGX_DIR` from `config.mk` when present, so a custom
AmgX install prefix only needs to be written once.

Then build and run:

```bash
make core-amgx
make examples-amgx
make run-amgx-c
make run-amgx-fortran
```

The prepare script uses these defaults, which can be overridden from the
environment:

```bash
AMGX_GIT_URL=https://github.com/NVIDIA/AMGX.git
AMGX_GIT_REF=main
AMGX_CUDA_ARCH=80
AMGX_NO_MPI=ON
```

On the A100 server used for this extract, `config.mk` can contain:

```make
CUDA_HOME ?= /apps/cuda/12.9.1
AMGX_CUDA_ARCH ?= 80
AMGX_BUILD_JOBS ?= 8
```

Then run:

```bash
make amgx-install
source src/amgx_setup/env_amgx.sh
```

This creates `amgx_local/source`, `amgx_local/build`, and
`amgx_local/install`. The whole `amgx_local/` directory is local generated
state and is ignored by git.

All core paths together:

```bash
make run-all
```

The AmgX runtime looks for `amgx_config.json` in the current run directory; the
Makefile copies `examples/amgx_config/amgx_config.json` before execution.

Compatibility aliases are still available: `make test` maps to `make run`, and
`make test-all` maps to `make run-all`.

## Link Notes

CUDA 12+ usually does not need `-lnvToolsExt`. If an older CUDA installation
requires it, set this in `config.mk`:

```make
NVTX_LIBS ?= -lnvToolsExt
```
