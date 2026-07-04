/*
 * Shared CUDA helper declarations.
 * Exposes cuSPARSE SpMV/SpSV wrappers and custom CUDA kernels used by the
 * diagonal and iLU BiCGStab solvers.
 */
#include <cusparse.h>

void coo_to_csr(const double* A, int* A_Rowindx, int* A_Colindx, double* A_val, int NNZ_A, int N, int* A_Rowpnt);

void make_device_matrix(const int* A_Rowindx, const int* A_Rowpnt, const int* A_Colindx, const double* A_val,
                        int*& d_A_Rowindx, int*& d_A_Rowpnt, int*& d_A_Colindx, double*& d_A_val,
                        int NNZ_A, int N);
void clean_device_matrix(int*& d_A_Rowindx, int*& d_A_Rowpnt, int*& d_A_Colindx, double*& d_A_val);

void make_device_vector(const double* x, double*& d_x, int N);
void clean_device_vector(double*& d_x);

void kkh_cuspmv_init(cusparseHandle_t& handle, cusparseSpMatDescr_t& matA, void*& dBuffer,
                     int* d_A_Rowpnt, int* d_A_Colindx, double* d_A_val,
                     double* d_x, double* d_b, int NNZ_A, int N);
void kkh_cuspmv_clean(cusparseHandle_t& handle, cusparseSpMatDescr_t& matA, void*& dBuffer);
void kkh_cuspmv(double* d_b, cusparseSpMatDescr_t& matA, double* d_x, cusparseHandle_t& handle, void* dBuffer, int N);

void kkh_cuspsv_init(cusparseHandle_t& handleL, cusparseSpMatDescr_t& matL, void*& dBufferL, cusparseSpSVDescr_t& spsvDescrL,
                     cusparseFillMode_t fill, cusparseDiagType_t diag,
                     int* d_L_Rowindx, int* d_L_Rowpnt, int* d_L_Colindx, double* d_L_val,
                     double* d_Ux, double* d_b, int NNZ_L, int N);
void kkh_cuspsv_clean(cusparseHandle_t& handleL, cusparseSpMatDescr_t& matL, void*& dBufferL, cusparseSpSVDescr_t& spsvDescrL);
void kkh_cuspsv(double* d_Ux, cusparseSpMatDescr_t& matL, double* d_b, cusparseHandle_t& handleL, void*& dBufferL, cusparseSpSVDescr_t& spsvDescrL, int N);

__global__ void kkh_cuvecmul(double *c, double *a,  double *b,  int n);
__global__ void kkh_cuvecadd(double *c, double *a,  double *b,  int n, double alpha);
__global__ void kkh_cuinvdiagA(double *c, int* d_A_Rowpnt, int* d_A_Colindx, double* d_A_val,  int n,  int m);


__global__ void kkh_cuvecadd_device(double *c, double *a,  double *b,  int n, double *alpha);
__global__ void kkh_cuscalar_div(double *result, double *mresult, double* d_A, double* d_B);
__global__ void kkh_cuscalar_divmul(double *result, double* d_A1, double* d_A2, double* d_B1, double* d_B2);
__global__ void kkh_cucheck(double *rr1, double *rr0sq, double epssq, bool *d_flag);
__global__ void kkh_cuscalar_copy(double *a, double *b);

__global__ void kkh_cuvecadd_stride_device(double *c, double *a,  double *b,  int n, int stride, double *alpha);
__global__ void kkh_cuvecadd_ilp_device(double *c, const double *a, const double *b, int n, double *alpha);

void kkh_cuspsv_init2(cusparseHandle_t& handleL, cusparseSpMatDescr_t& matL, void*& dBufferL, cusparseSpSVDescr_t& spsvDescrL,
                     cusparseFillMode_t fill, cusparseDiagType_t diag,
                     int* d_L_Rowpnt, int* d_L_Colindx, double* d_L_val,
                     double* d_Ux, double* d_b, int NNZ_L, int N);
