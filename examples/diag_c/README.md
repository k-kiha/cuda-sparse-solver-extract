# Diagonal BiCGStab C Example

This C caller allocates CUDA device memory directly, uploads CSR data from
`examples/data/small_csr`, and calls the common `kisti_solver_c` ABI.

Build and run:

```bash
make run-diag-c
```

Linked core path:

```text
examples/diag_c/main.c
-> libkisti_solver_c.so
-> src/kisti_solver_c.cu
-> src/solver3_diagbicg
```
