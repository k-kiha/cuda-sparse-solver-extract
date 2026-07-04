# Runnable Examples

The example directories are thin callers for the core implementation in `src`.
They all solve the small CSR `A x = b` case from `examples/data/small_csr`.

| Example | Linked solver library | Core path |
|---|---|---|
| `diag_c` | `libkisti_solver_c.so` | diagonal BiCGStab |
| `diag_fortran` | `libkisti_solver_c.so` | diagonal BiCGStab |
| `ilu_c` | `libkisti_solver_c_ilu.so` | iLU(0) + cuSPARSE SpSV BiCGStab |
| `ilu_fortran` | `libkisti_solver_c_ilu.so` | iLU(0) + cuSPARSE SpSV BiCGStab |
| `amgx_c` | `libkisti_solver_c_amgx.so` | AmgX AMG/GMRES path |
| `amgx_fortran` | `libkisti_solver_c_amgx.so` | AmgX AMG/GMRES path |

`_common/fortran` is not a standalone example. It is the shared `bind(C)`
adapter used by the Fortran examples.

Build only the no-AmgX example executables:

```bash
make examples
```

Run the no-AmgX examples:

```bash
make run
```

The CUPID-like application bridge is kept in `src/cupid_gfortran_bridge/`, not
in this examples directory.
