# Fortran CSR Example

This is the main interface showcase.

`main.f90` reads a CSR matrix from `Mtest/`, allocates host arrays, calls
`mod_kisti`, and reaches the CUDA shared library through a `bind(C)` interface.
`src/fortran/mod_kisti.f90` owns the NVFORTRAN `device` arrays and passes those
device pointers to the same `kisti_solver_c` ABI used by the C example.

Run through the top-level Makefile:

```bash
make example-fortran
make test
```
