# Repo-Local AmgX Setup

AmgX is one of the core solver paths in this extract. This directory only
manages the external AmgX dependency required to build and run that path.

Default locations:

```text
external/AMGX/   cloned NVIDIA/AMGX source tree, ignored by git
.local/amgx/     local AmgX install prefix, ignored by git
```

Prepare AmgX locally without using Make:

```bash
tools/amgx/prepare_amgx.sh
source tools/amgx/env_amgx.sh
```

The prepare script clones or updates `AMGX_GIT_URL`, checks out
`AMGX_GIT_REF`, builds AmgX, installs it into `.local/amgx`, and verifies that
`libamgxsh.so` exists.

Defaults:

```text
AMGX_GIT_URL=https://github.com/NVIDIA/AMGX.git
AMGX_GIT_REF=main
AMGX_CUDA_ARCH=80
AMGX_NO_MPI=ON
```

Example for the A100 server with CUDA 12.9.1:

```bash
CUDA_HOME=/apps/cuda/12.9.1 tools/amgx/prepare_amgx.sh
source tools/amgx/env_amgx.sh
```

The old Make wrapper is still available:

```bash
make amgx-install
source tools/amgx/env_amgx.sh
```

Build and run the AmgX core path:

```bash
make lib-amgx
make run-amgx-c
make run-amgx-fortran
```

For an NVIDIA A100 server, the default `AMGX_CUDA_ARCH` is `80`.
