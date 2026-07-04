/*
 * AmgX one-shot solve ABI.
 * Uses the AmgX C API with CUDA device pointers supplied by kisti_solver_c.
 */
extern "C" {

void kkh_cuAmgX(int n, int nnz,
                const int *d_rowPtr,
                const int *d_colInd,
                const double *d_val,
                double *d_vec);
}
