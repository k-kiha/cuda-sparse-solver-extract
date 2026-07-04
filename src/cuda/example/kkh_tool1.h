/*
 * Minimal cuSPARSE helper declarations for the example solver skeleton.
 */
#include <cusparse.h>

extern "C" {

// 함수1: matA, handle, dBuffer를 초기화
void kkh_tool1_cusparse_init(
    int n, int m,
    int *A_ipnt, int *A_jinx, double *A_val, double *x,
    cusparseSpMatDescr_t *matA,
    cusparseHandle_t *handle,
    void **dBuffer,
    double *Ax);

// 함수2: SpMV 수행 (Ax = A * x)
void kkh_tool1_cusparse(
    cusparseSpMatDescr_t matA,
    cusparseHandle_t handle,
    void *dBuffer,
    int m, int n,
    double *x, double *Ax);

// 함수3: 자원 정리
void kkh_tool1_cusparse_finish(
    cusparseSpMatDescr_t matA,
    cusparseHandle_t handle,
    void *dBuffer);

__global__ void kkh_tool1_vec_mul( double *a,  double *b,  double *c, int n);
__global__ void kkh_tool1_vec_add( double *a,  double *b,  double *c, int n, double alpha);

}
