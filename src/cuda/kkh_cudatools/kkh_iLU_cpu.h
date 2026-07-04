/*
 * CPU iLU(0) helper declarations for the cuSPARSE SpSV core path.
 * The public helper copies device CSR to host, computes L/U, then uploads
 * separate L/U CSR arrays back to CUDA device memory.
 */
#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>

int find_in_row(int row, int col,
                       const int *rowPtr, const int *colInd);

void ilu0_factor(
    int n, int nnz,
    const int *rowPtr, const int *colInd, const double *Aval,
    double *Lval, double *Uval, double *Udiag
);

void split_LU_to_separate_csr(
    int n,
    const int *rowPtr, const int *colInd,
    const double *Lval, const double *Uval,
    int **LrowPtr, int **LcolInd, double **Lval_out, int *nnzL,
    int **UrowPtr, int **UcolInd, double **Uval_out, int *nnzU
);

void print_csr(
    const char *name, int n,
    const int *rowPtr, const int *colInd, const double *val);

void print_diag_U(int n, const double *Udiag);


void kkh_iLU_cpu_ilu0(
    const int n, const int m, 
    const int *A_ipnt, const int *A_jinx, const double *A_val,
    int **L_rowPtr, int **L_colInd, double **L_val,
    int **U_rowPtr, int **U_colInd, double **U_val,
    int *nnzL, int *nnzU
);
