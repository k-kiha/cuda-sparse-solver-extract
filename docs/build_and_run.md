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
make test
```

Individual targets:

```bash
make test-diag-c
make test-diag-fortran
make test-ilu-c
make test-ilu-fortran
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

Or install into the repo-local prefix:

```bash
make amgx-install
source tools/amgx/env_amgx.sh
```

Then run:

```bash
make test-amgx-c
make test-amgx-fortran
```

All core paths together:

```bash
make test-all
```

The AmgX runtime looks for `amgx_config.json` in the current run directory; the
Makefile copies `examples/amgx_config/amgx_config.json` before execution.

## Link Notes

CUDA 12+ usually does not need `-lnvToolsExt`. If an older CUDA installation
requires it, set this in `config.mk`:

```make
NVTX_LIBS ?= -lnvToolsExt
```
