# C CSR Example

This example calls the same public C ABI directly:

```c
void kisti_solver_c(int n, int m, int *d_rowPtr, int *d_colInd, double *d_val, double *d_vec);
```

It demonstrates that the CUDA solver can be reused from C without the Fortran
wrapper. The C caller allocates CUDA runtime device memory itself, then passes
the same device-pointer ABI that `src/fortran/mod_kisti.f90` reaches through
`bind(C)`.

Run through the top-level Makefile:

```bash
make example-c
make test
```
