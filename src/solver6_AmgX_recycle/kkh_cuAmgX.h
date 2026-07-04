/*
 * AmgX coefficient-reuse solve ABI.
 * Uses the AmgX C API to demonstrate setup, coefficient replacement, and reuse.
 */
extern "C" {

void kkh_cuAmgX(int n, int nnz,
                const int *d_rowPtr,
                const int *d_colInd,
                const double *d_val,
                double *d_vec);
}
