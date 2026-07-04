# AmgX C Example

This C caller uses the same device-pointer ABI and links against the AmgX
solver library. AmgX must be installed or built through `tools/amgx`.

Build and run:

```bash
make test-amgx-c
```

Linked core path:

```text
examples/amgx_c/main.c
-> libkisti_solver_c_amgx.so
-> src/kisti_solver_c.cu built with KISTI_SOLVER_AMGX
-> src/solver6_AmgX_recycle
```
