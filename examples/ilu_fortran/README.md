# iLU(0) + SpSV Fortran Example

This Fortran caller reaches the iLU solver through the same `bind(C)` interface
used by the diagonal path. The difference is the linked solver library.

Build and run:

```bash
make test-ilu-fortran
```

Linked core path:

```text
examples/ilu_fortran/main.f90
-> examples/fortran_common/mod_kisti.f90
-> libkisti_solver_c_ilu.so
-> src/solver7_iLU
```
