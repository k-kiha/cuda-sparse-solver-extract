/*
 * Public C ABI for the CUDA sparse solver showcase.
 * All pointer arguments are CUDA device pointers. Fortran reaches this ABI
 * through bind(C); C callers include this header directly.
 */
void kisti_solver_c(int n, int m, int *d_rowPtr, int *d_colInd, double *d_val, double *d_vec);
