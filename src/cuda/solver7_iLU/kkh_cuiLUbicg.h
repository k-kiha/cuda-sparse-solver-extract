/*
 * Optional iLU(0)-preconditioned BiCGStab solver ABI.
 * Uses cuSPARSE SpSV lower/upper solves, cuSPARSE SpMV, and cuBLAS Ddot.
 */
extern "C" {

void kkh_cuiLUbicg(int n, int m, int *d_rowPtr, int *d_colInd, double *d_val, double *d_vec);

}
