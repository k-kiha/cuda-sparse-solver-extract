# Repo-Local AmgX Setup

This directory is reserved for optional AmgX dependency management.

The core solver path does not require AmgX:

```bash
make
make test
```

To build the optional AmgX path later, install AmgX into the repository-local
prefix:

```bash
make amgx-install
make amgx
```

Default locations:

```text
external/AMGX/   cloned NVIDIA/AMGX source tree, ignored by git
.local/amgx/     local AmgX install prefix, ignored by git
```

For an NVIDIA A100 server, the default `AMGX_CUDA_ARCH` is `80`.

