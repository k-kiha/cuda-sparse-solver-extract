# Diagonal BiCGStab Fortran Example

This Fortran caller uses `src/fortran/mod_kisti.f90` to allocate NVFORTRAN
device arrays and call the same `kisti_solver_c` ABI through `bind(C)`.

Build and run:

```bash
make test-diag-fortran
```

Linked core path:

```text
examples/diag_fortran/main.f90
-> src/fortran/mod_kisti.f90
-> libkisti_solver_c.so
-> src/cuda/solver3_diagbicg
```
