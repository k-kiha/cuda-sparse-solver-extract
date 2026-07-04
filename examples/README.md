# Runnable Examples

The examples are thin callers for the core implementation in `src`.
They all solve the small CSR `A x = b` case from `data/small_csr`.

| Example | Linked solver library | Core path |
|---|---|---|
| `diag_c` | `libkisti_solver_c.so` | diagonal BiCGStab |
| `diag_fortran` | `libkisti_solver_c.so` | diagonal BiCGStab |
| `ilu_c` | `libkisti_solver_c_ilu.so` | iLU(0) + cuSPARSE SpSV BiCGStab |
| `ilu_fortran` | `libkisti_solver_c_ilu.so` | iLU(0) + cuSPARSE SpSV BiCGStab |
| `amgx_c` | `libkisti_solver_c_amgx.so` | AmgX AMG/GMRES path |
| `amgx_fortran` | `libkisti_solver_c_amgx.so` | AmgX AMG/GMRES path |

`cupid_gfortran_bridge` is an integration reference for a CUPID-like
application build. It is separate from the minimal solver smoke tests.
