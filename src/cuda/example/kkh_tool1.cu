/*
 * Minimal cuSPARSE helper for the example solver skeleton.
 * Role: keep a compact CSR SpMV setup/call/cleanup example plus simple custom
 * vector kernels.
 */
#include <stdio.h>
#include <cuda_runtime.h>
#include <cusparse.h>

extern "C" {
// 함수1: matA, handle, dBuffer를 초기화
void kkh_tool1_cusparse_init(
    int n, int m,
    int *A_ipnt, int *A_jinx, double *A_val, double *x,
    cusparseSpMatDescr_t *matA,
    cusparseHandle_t *handle,
    void **dBuffer,
    double *Ax)
{
    size_t bufferSize;
    int nnz = 0;
    // [CUDA Runtime] Read CSR nnz from device row pointer.
    cudaMemcpy(&nnz, &A_ipnt[n], sizeof(int), cudaMemcpyDeviceToHost);

    // [cuSPARSE] Build CSR matrix descriptor for SpMV.
    cusparseCreateCsr(matA, n, m, nnz,
                      A_ipnt, A_jinx, A_val,
                      CUSPARSE_INDEX_32I, CUSPARSE_INDEX_32I,
                      CUSPARSE_INDEX_BASE_ZERO, CUDA_R_64F);

    cusparseDnVecDescr_t vecX, vecY;
    cusparseCreate(handle);

    cusparseCreateDnVec(&vecX, m, x, CUDA_R_64F);
    cusparseCreateDnVec(&vecY, n, Ax, CUDA_R_64F);

    double alpha = 1.0;
    double beta = 0.0;

    // [cuSPARSE] Query SpMV buffer for Ax = A*x.
    cusparseSpMV_bufferSize(*handle,
                            CUSPARSE_OPERATION_NON_TRANSPOSE,
                            &alpha, *matA, vecX, &beta, vecY,
                            CUDA_R_64F, CUSPARSE_SPMV_CSR_ALG1,
                            &bufferSize);
    cudaMalloc(dBuffer, bufferSize);

    cusparseDestroyDnVec(vecX);
    cusparseDestroyDnVec(vecY);
}

// 함수2: SpMV 수행 (Ax = A * x)
void kkh_tool1_cusparse(
    cusparseSpMatDescr_t matA,
    cusparseHandle_t handle,
    void *dBuffer,
    int m, int n,
    double *x, double *Ax)
{
    cusparseDnVecDescr_t vecX, vecY;
    double alpha = 1.0;
    double beta = 0.0;

    cusparseCreateDnVec(&vecX, m, x, CUDA_R_64F);
    cusparseCreateDnVec(&vecY, n, Ax, CUDA_R_64F);

    // [cuSPARSE] CSR SpMV call.
    cusparseSpMV(handle,
                 CUSPARSE_OPERATION_NON_TRANSPOSE,
                 &alpha, matA, vecX, &beta, vecY,
                 CUDA_R_64F, CUSPARSE_SPMV_CSR_ALG1,
                 dBuffer);

    cusparseDestroyDnVec(vecX);
    cusparseDestroyDnVec(vecY);
}

// 함수3: 자원 정리
void kkh_tool1_cusparse_finish(
    cusparseSpMatDescr_t matA,
    cusparseHandle_t handle,
    void *dBuffer)
{
    cudaFree(dBuffer);
    cusparseDestroySpMat(matA);
    cusparseDestroy(handle);
}

__global__ void kkh_tool1_vec_mul( double *a,  double *b,  double *c, int n)
{
    // [CUDA Kernel] One thread per element: c[i] = a[i] * b[i].
    int idx = threadIdx.x + blockDim.x * blockIdx.x;
    if (idx < n) {
        c[idx] = a[idx] * b[idx];
    }
}
__global__ void kkh_tool1_vec_add( double *a,  double *b,  double *c, int n, double alpha)
{
    // [CUDA Kernel] One thread per element: c[i] = a[i] + alpha*b[i].
    int idx = threadIdx.x + blockDim.x * blockIdx.x;
    if (idx < n) {
        c[idx] = a[idx] + alpha* b[idx];
    }
}

}


// // 메인 계산 함수
// void EXAMPLE_solver(int n, int m, int *A_ipnt, int *A_jinx, double *A_val, double *x)
// {
//     cusparseHandle_t handle = NULL;
//     cusparseSpMatDescr_t matA;

//     size_t bufferSize = 0;
//     void *dBuffer = NULL;

//     double *Ax;
//     cudaMalloc((void**)&Ax, n * sizeof(double));
//     cudaMemset(Ax, 0, n * sizeof(double));

//     // 함수1 호출: 초기화
//     init_matvec_environment(n, m, A_ipnt, A_jinx, A_val, x, &matA, &handle, &dBuffer, &bufferSize, Ax);

//     // 함수2 호출: SpMV 수행
//     perform_spmv(matA, handle, dBuffer, m, n, x, Ax);

//     // 결과 복사
//     cudaMemcpy(x, Ax, n * sizeof(double), cudaMemcpyDeviceToDevice);

//     // 함수3 호출: 자원 해제
//     cleanup_matvec_environment(matA, handle, dBuffer);

//     cudaFree(Ax);
// }
