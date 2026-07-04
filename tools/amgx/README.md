# Repo-Local AmgX Setup

AmgX is one of the core solver paths in this extract. This directory only
manages the external AmgX dependency required to build and run that path.

Default locations:

```text
external/AMGX/   cloned NVIDIA/AMGX source tree, ignored by git
.local/amgx/     local AmgX install prefix, ignored by git
```

Install AmgX locally:

```bash
make amgx-install
source tools/amgx/env_amgx.sh
```

Build and run the AmgX core path:

```bash
make lib-amgx
make test-amgx-c
make test-amgx-fortran
```

For an NVIDIA A100 server, the default `AMGX_CUDA_ARCH` is `80`.
