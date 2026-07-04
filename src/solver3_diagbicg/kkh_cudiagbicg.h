/*
 * Default diagonal-preconditioned BiCGStab solver ABI.
 * Uses cuSPARSE SpMV, cuBLAS Ddot, custom CUDA kernels, and NVTX ranges.
 */
extern "C" {

void kkh_cudiagbicg(int n, int m, int *d_rowPtr, int *d_colInd, double *d_val, double *d_vec);

}
