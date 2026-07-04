# iLU(0) + SpSV C Example

This C caller is intentionally the same ABI shape as `diag_c`; the solver
changes through the linked library.

Build and run:

```bash
make test-ilu-c
```

Linked core path:

```text
examples/ilu_c/main.c
-> libkisti_solver_c_ilu.so
-> src/cuda/kisti_solver_c.cu built with KISTI_SOLVER_ILU
-> src/cuda/solver7_iLU
```
