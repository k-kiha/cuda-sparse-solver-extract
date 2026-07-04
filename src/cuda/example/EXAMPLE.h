/*
 * Minimal example solver ABI.
 * Shows how another CUDA solver could plug into the same device-pointer style.
 */
extern "C" {

void EXAMPLE_solver(int n, int m, int *d_rowPtr, int *d_colInd, double *d_val, double *d_vec);

}
