# Diagonal BiCGStab C Example

This C caller allocates CUDA device memory directly, uploads CSR data from
`data/small_csr`, and calls the common `kisti_solver_c` ABI.

Build and run:

```bash
make test-diag-c
```

Linked core path:

```text
examples/diag_c/main.c
-> libkisti_solver_c.so
-> src/cuda/kisti_solver_c.cu
-> src/cuda/solver3_diagbicg
```
