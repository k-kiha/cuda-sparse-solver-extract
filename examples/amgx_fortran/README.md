# AmgX Fortran Example

This Fortran caller reaches the AmgX solver path through `mod_kisti` and the
same `kisti_solver_c` ABI.

Build and run:

```bash
make test-amgx-fortran
```

Linked core path:

```text
examples/amgx_fortran/main.f90
-> examples/fortran_common/mod_kisti.f90
-> libkisti_solver_c_amgx.so
-> src/solver6_AmgX_recycle
```
