/*
 * iLU(0) factorization helper for the SpSV core path.
 * Role: copy device CSR data to host, compute CPU iLU(0), split L/U into CSR,
 * then upload L/U CSR data back to the GPU for cuSPARSE SpSV.
 * Uses: CUDA Runtime memcpy/allocation around CPU factorization.
 */
#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>

int find_in_row(int row, int col,
                       const int *rowPtr, const int *colInd)
{
    int lo = rowPtr[row], hi = rowPtr[row+1] - 1;
    while (lo <= hi) {
        int mid = (lo + hi) >> 1;
        if (colInd[mid] == col) return mid;
        if (colInd[mid] <  col) lo = mid + 1;
        else                     hi = mid - 1;
    }
    return -1;
}

void ilu0_factor(
    int n, int nnz,
    const int *rowPtr, const int *colInd, const double *Aval,
    double *Lval, double *Uval, double *Udiag
)
{
    for (int i = 0; i < nnz; ++i) { Lval[i] = 0.0; Uval[i] = 0.0; }
    for (int i = 0; i < n;   ++i) Udiag[i] = 0.0;

    for (int i = 0; i < n; ++i) {
        for (int p = rowPtr[i]; p < rowPtr[i+1]; ++p) {
            int j = colInd[p];
            double aij = Aval[p];

            if (j < i) {
                double sum = aij;
                for (int pk = rowPtr[i]; pk < rowPtr[i+1]; ++pk) {
                    int k = colInd[pk];
                    if (k >= j) break;
                    int kj = find_in_row(k, j, rowPtr, colInd);
                    if (kj >= 0) sum -= Lval[pk] * Uval[kj];
                }
                if (Udiag[j] == 0.0) {
                    fprintf(stderr, "[ILU0] Zero diagonal detected at U(%d,%d).\n", j, j);
                }
                Lval[p] = sum / Udiag[j];
            } else {
                double sum = aij;
                for (int pk = rowPtr[i]; pk < rowPtr[i+1]; ++pk) {
                    int k = colInd[pk];
                    if (k >= i) break;
                    int kj = find_in_row(k, j, rowPtr, colInd);
                    if (kj >= 0) sum -= Lval[pk] * Uval[kj];
                }
                Uval[p] = sum;
                if (j == i) Udiag[i] = sum;
            }
        }
        if (Udiag[i] == 0.0) {
            int didx = find_in_row(i, i, rowPtr, colInd);
            if (didx < 0) fprintf(stderr, "[ILU0] Structural zero diagonal at row %d (no A(%d,%d)).\n", i, i, i);
            else          fprintf(stderr, "[ILU0] Numerical zero diagonal at row %d.\n", i);
        }
    }
}

/* -------- NEW: Split L and U into separate CSR --------
   Inputs:
     n, rowPtr, colInd: original CSR structure
     Lval, Uval: values computed by ilu0_factor on the same structure
   Outputs (allocated inside; caller must free):
     LrowPtr(n+1), LcolInd(nnzL), Lval_out(nnzL)  -- strictly lower only
     UrowPtr(n+1), UcolInd(nnzU), Uval_out(nnzU)  -- upper incl. diagonal
     *nnzL, *nnzU: counts
   Note:
     This keeps the original relative order (stable split).
*/
void split_LU_to_separate_csr(
    int n,
    const int *rowPtr, const int *colInd,
    const double *Lval, const double *Uval,
    int **LrowPtr, int **LcolInd, double **Lval_out, int *nnzL,
    int **UrowPtr, int **UcolInd, double **Uval_out, int *nnzU
)
{
    // 1) Count nnzL, nnzU per row
    int *Lrp = (int*)malloc((n+1) * sizeof(int));
    int *Urp = (int*)malloc((n+1) * sizeof(int));
    if (!Lrp || !Urp) { fprintf(stderr, "alloc failed\n"); exit(1); }

    Lrp[0] = 0; Urp[0] = 0;
    for (int i = 0; i < n; ++i) {
        int cntL = 0, cntU = 0;
        for (int p = rowPtr[i]; p < rowPtr[i+1]; ++p) {
            int j = colInd[p];
            if (j < i) ++cntL;        // strictly lower (no diagonal)
            else       ++cntU;        // upper incl diagonal
        }
        Lrp[i+1] = Lrp[i] + cntL;
        Urp[i+1] = Urp[i] + cntU;
    }
    *nnzL = Lrp[n];
    *nnzU = Urp[n];

    int *Lci = (int*)malloc((*nnzL) * sizeof(int));
    int *Uci = (int*)malloc((*nnzU) * sizeof(int));
    double *Lva = (double*)malloc((*nnzL) * sizeof(double));
    double *Uva = (double*)malloc((*nnzU) * sizeof(double));
    if ((!Lci || !Uci || !Lva || !Uva) && ((*nnzL)+(*nnzU) > 0)) {
        fprintf(stderr, "alloc failed\n"); exit(1);
    }

    // 2) Fill
    // Use running pointers per row
    for (int i = 0; i < n; ++i) {
        int lpos = Lrp[i];
        int upos = Urp[i];
        for (int p = rowPtr[i]; p < rowPtr[i+1]; ++p) {
            int j = colInd[p];
            if (j < i) {
                Lci[lpos] = j;
                Lva[lpos] = Lval[p];          // strictly lower value
                ++lpos;
            } else {
                Uci[upos] = j;
                Uva[upos] = Uval[p];          // upper (including diag)
                ++upos;
            }
        }
    }

    // 3) Return
    *LrowPtr = Lrp;  *LcolInd = Lci;  *Lval_out = Lva;
    *UrowPtr = Urp;  *UcolInd = Uci;  *Uval_out = Uva;
}

// (optional) simple printers
void print_csr(
    const char *name, int n,
    const int *rowPtr, const int *colInd, const double *val)
{
    printf("\n=== %s ===\n", name);
    for (int i = 0; i < n; ++i) {
        printf("row %d:", i);
        for (int p = rowPtr[i]; p < rowPtr[i+1]; ++p) {
            printf("  (%d,%d)=%.6g", i, colInd[p], val[p]);
        }
        printf("\n");
    }
}

void print_diag_U(int n, const double *Udiag) {
    printf("\nDiagonal(U):");
    for (int i = 0; i < n; ++i) printf("  U(%d,%d)=%.6g", i, i, Udiag[i]);
    printf("\n");
}
// ---------------------------------------------------------


void kkh_iLU_cpu_ilu0(
    const int n, const int m, 
    const int *A_ipnt, const int *A_jinx, const double *A_val,
    int **L_rowPtr, int **L_colInd, double **L_val,
    int **U_rowPtr, int **U_colInd, double **U_val,
    int *nnzL, int *nnzU
){

    ////---- CU SPARSE iLU factorization on CPU ---- {{{
    int *host_L_rpnt = NULL, *host_L_cindx = NULL, *host_U_rpnt = NULL, *host_U_cindx = NULL;
    double *host_L_val = NULL, *host_U_val = NULL;

    int *host_A_ipnt = (int*)malloc((n+1) * sizeof(int));
    int *host_A_jinx = (int*)malloc(m * sizeof(int));
    double *host_A_val = (double*)malloc(m * sizeof(double));

    // [CUDA Runtime] Download input device CSR to host for CPU iLU(0).
    cudaMemcpy(host_A_ipnt, A_ipnt, (n+1) * sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(host_A_jinx, A_jinx, m * sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(host_A_val, A_val, m * sizeof(double), cudaMemcpyDeviceToHost);

    double *host_Lall  = (double*)malloc(sizeof(double)*m);
    double *host_Uall  = (double*)malloc(sizeof(double)*m);
    double *Udiag = (double*)malloc(sizeof(double)*n);

    ilu0_factor(n, m, host_A_ipnt, host_A_jinx, host_A_val, host_Lall, host_Uall, Udiag);

    split_LU_to_separate_csr(
        n, host_A_ipnt, host_A_jinx, host_Lall, host_Uall,
        &host_L_rpnt, &host_L_cindx, &host_L_val, nnzL,
        &host_U_rpnt, &host_U_cindx, &host_U_val, nnzU
    );

    // cleanup
    free(host_Lall); free(host_Uall); free(Udiag);
    free(host_A_ipnt);
    free(host_A_jinx);
    free(host_A_val);

    // // Print (optional)
    // print_csr("L (strictly lower; unit diag implicit)", n, host_L_rpnt, host_L_cindx, host_L_val);
    // print_csr("U (including diagonal)",                 n, host_U_rpnt, host_U_cindx, host_U_val);
    
    // [CUDA Runtime] Upload split L/U CSR factors for cuSPARSE SpSV.
    cudaMalloc((void**)L_rowPtr, sizeof(int)    * (n + 1));
    cudaMalloc((void**)L_colInd, sizeof(int)    * (*nnzL));
    cudaMalloc((void**)L_val , sizeof(double) * (*nnzL));
    cudaMalloc((void**)U_rowPtr, sizeof(int)    * (n + 1));
    cudaMalloc((void**)U_colInd, sizeof(int)    * (*nnzU));
    cudaMalloc((void**)U_val , sizeof(double) * (*nnzU));

    cudaMemcpy(*L_rowPtr, host_L_rpnt , sizeof(int)    * (n + 1), cudaMemcpyHostToDevice);
    cudaMemcpy(*L_colInd, host_L_cindx, sizeof(int)    * (*nnzL), cudaMemcpyHostToDevice);
    cudaMemcpy(*L_val   , host_L_val  , sizeof(double) * (*nnzL), cudaMemcpyHostToDevice);
    cudaMemcpy(*U_rowPtr, host_U_rpnt , sizeof(int)    * (n + 1), cudaMemcpyHostToDevice);
    cudaMemcpy(*U_colInd, host_U_cindx, sizeof(int)    * (*nnzU), cudaMemcpyHostToDevice);
    cudaMemcpy(*U_val   , host_U_val  , sizeof(double) * (*nnzU), cudaMemcpyHostToDevice);

    free(host_L_rpnt); free(host_L_cindx); free(host_L_val);
    free(host_U_rpnt); free(host_U_cindx); free(host_U_val);
    ////---- CU SPARSE iLU factorization on CPU ---- }}}
}
