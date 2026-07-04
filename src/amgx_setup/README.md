# AmgX Dependency Setup

AmgX is one of the core solver paths in this extract. This directory contains
only the scripts that prepare the external AmgX dependency. The actual AmgX
solver wrapper code is under `src/solver6_AmgX_recycle`.

Default locations:

```text
amgx_local/source/    cloned NVIDIA/AMGX source tree, ignored by git
amgx_local/build/     CMake build tree, ignored by git
amgx_local/install/   local AmgX install prefix, ignored by git
```

Recommended path: put CUDA and AmgX settings in `config.mk`, then prepare AmgX
through Make so those values are used:

```bash
make amgx-install
source src/amgx_setup/env_amgx.sh
```

`env_amgx.sh` reads `AMGX_DIR` from `config.mk` when it is present. If
`AMGX_DIR` is already exported in the shell, that environment value takes
priority.

The prepare script clones or updates `AMGX_GIT_URL`, checks out
`AMGX_GIT_REF`, builds AmgX, installs it into `amgx_local/install`, and
verifies that `libamgxsh.so` exists.

Defaults:

```text
AMGX_GIT_URL=https://github.com/NVIDIA/AMGX.git
AMGX_GIT_REF=main
AMGX_CUDA_ARCH=80
AMGX_NO_MPI=ON
```

Example `config.mk` entries for the A100 server with CUDA 12.9.1:

```make
CUDA_HOME ?= /apps/cuda/12.9.1
AMGX_CUDA_ARCH ?= 80
AMGX_BUILD_JOBS ?= 8
```

Direct script execution is also available, but it reads environment variables
rather than `config.mk`:

```bash
CUDA_HOME=/apps/cuda/12.9.1 src/amgx_setup/prepare_amgx.sh
source src/amgx_setup/env_amgx.sh
```

Build and run the AmgX core path:

```bash
make lib-amgx
make run-amgx-c
make run-amgx-fortran
```

For an NVIDIA A100 server, the default `AMGX_CUDA_ARCH` is `80`.
