# Fortran Example Adapter

`mod_kisti.f90` is the shared NVFORTRAN adapter used by the Fortran examples.
It allocates CUDA device arrays, loads the small CSR input, and calls the same
`kisti_solver_c` C ABI used by the C examples.

This file lives under `_common` because it is support code for examples, not a
separate solver path.
