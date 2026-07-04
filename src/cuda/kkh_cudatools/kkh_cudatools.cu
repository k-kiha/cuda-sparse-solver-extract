/*
 * CUDA sparse helper layer.
 * Role: own reusable CUDA Runtime allocation/copy helpers, cuSPARSE SpMV/SpSV
 * wrappers, custom vector/scalar kernels, and NVTX ranges used by the solvers.
 */
#include <cuda_runtime.h>
#include <cusparse.h>
#include <iostream>
#include "kkh_cudatools.h"

#include <nvtx3/nvToolsExt.h>

void coo_to_csr(const double* A, int* A_Rowindx, int* A_Colindx, double* A_val, int NNZ_A, int N, int* A_Rowpnt)
    { // COO to CSR 변환
            int index = 0;
            int countA = 0;

            for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++)
            {
                index = i * N + j;
                if(A[index]!=0){
                    A_Rowindx[countA] = i;
                    A_Colindx[countA] = j;
                    A_val[countA] = A[index];
                    countA++;
                }
            }
            
            // [CUDA Runtime] COO row index and CSR offset work buffers.
            int *d_coo_rows_A, *d_csr_offsets_A;
            cudaMalloc((void**)&d_coo_rows_A, NNZ_A * sizeof(int));
            cudaMalloc((void**)&d_csr_offsets_A, (N + 1) * sizeof(int));
            cudaMemcpy(d_coo_rows_A, A_Rowindx, NNZ_A * sizeof(int), cudaMemcpyHostToDevice);

            // [cuSPARSE] COO row indices -> CSR row offsets conversion.
            cusparseHandle_t handle_A;
            cusparseCreate(&handle_A);

            // COO → CSR 변환
            cusparseXcoo2csr(handle_A,d_coo_rows_A,NNZ_A,N,d_csr_offsets_A,CUSPARSE_INDEX_BASE_ZERO);

            // 결과 가져오기
            cudaMemcpy(A_Rowpnt, d_csr_offsets_A, (N + 1) * sizeof(int), cudaMemcpyDeviceToHost);

            // // 결과 출력
            // std::cout << "CSR row offsets: ";
            // for (int i = 0; i < N + 1; ++i) {
            //     std::cout << A_Rowpnt[i] << " ";
            // }
            // std::cout << std::endl;

            // 정리
            cudaFree(d_coo_rows_A);
            cudaFree(d_csr_offsets_A);
            cusparseDestroy(handle_A);
    }

void make_device_matrix(const int* A_Rowindx, const int* A_Rowpnt, const int* A_Colindx, const double* A_val,
                         int*& d_A_Rowindx, int*& d_A_Rowpnt, int*& d_A_Colindx, double*& d_A_val,
                         int NNZ_A, int N) {
    // [CUDA Runtime] Host CSR matrix upload helper.
    cudaMalloc(&d_A_Rowindx, sizeof(int) * NNZ_A);
    cudaMalloc(&d_A_Rowpnt , sizeof(int) * (N + 1));
    cudaMalloc(&d_A_Colindx, sizeof(int) * NNZ_A);
    cudaMalloc(&d_A_val    , sizeof(double) * NNZ_A);

    cudaMemcpy(d_A_Rowindx, A_Rowindx, sizeof(int) * NNZ_A, cudaMemcpyHostToDevice);
    cudaMemcpy(d_A_Rowpnt , A_Rowpnt , sizeof(int) * (N + 1), cudaMemcpyHostToDevice);
    cudaMemcpy(d_A_Colindx, A_Colindx, sizeof(int) * NNZ_A, cudaMemcpyHostToDevice);
    cudaMemcpy(d_A_val    , A_val    , sizeof(double) * NNZ_A, cudaMemcpyHostToDevice);
}

void clean_device_matrix(int*& d_A_Rowindx, int*& d_A_Rowpnt, int*& d_A_Colindx, double*& d_A_val) {
    cudaFree(d_A_Rowindx);
    cudaFree(d_A_Rowpnt);
    cudaFree(d_A_Colindx);
    cudaFree(d_A_val);
    d_A_Rowindx = nullptr;
    d_A_Rowpnt = nullptr;
    d_A_Colindx = nullptr;
    d_A_val = nullptr;
}

void make_device_vector(const double* x, double*& d_x, int N) {
    // [CUDA Runtime] Host vector upload helper.
    cudaMalloc(&d_x, sizeof(double) * N);
    cudaMemcpy(d_x, x, sizeof(double) * N, cudaMemcpyHostToDevice);
}

void clean_device_vector(double*& d_x) {
    cudaFree(d_x);
    d_x = nullptr;
}

void kkh_cuspmv_init(cusparseHandle_t& handle, cusparseSpMatDescr_t& matA, void*& dBuffer,
                     int* d_A_Rowpnt, int* d_A_Colindx, double* d_A_val,
                     double* d_x, double* d_b, int NNZ_A, int N) {

    double alpha = 1.0f, beta = 0.0f;
    size_t bufferSize;
    cusparseDnVecDescr_t vecX, vecB;

    // [cuSPARSE] Build CSR sparse matrix and dense vector descriptors for SpMV.
    cusparseCreate(&handle);

    cusparseCreateCsr(&matA, N, N, NNZ_A,
                      d_A_Rowpnt, d_A_Colindx, d_A_val,
                      CUSPARSE_INDEX_32I, CUSPARSE_INDEX_32I,
                      CUSPARSE_INDEX_BASE_ZERO, CUDA_R_64F);

    cusparseCreateDnVec(&vecX, N, d_x, CUDA_R_64F);
    cusparseCreateDnVec(&vecB, N, d_b, CUDA_R_64F);

    // [cuSPARSE] Query CSR SpMV workspace size.
    cusparseSpMV_bufferSize(handle, CUSPARSE_OPERATION_NON_TRANSPOSE,
                            &alpha, matA, vecX, &beta, vecB,
                            CUDA_R_64F, CUSPARSE_SPMV_CSR_ALG1, &bufferSize);
    cudaMalloc(&dBuffer, bufferSize);

    cusparseDestroyDnVec(vecX);
    cusparseDestroyDnVec(vecB);
} 

void kkh_cuspmv_clean(cusparseHandle_t& handle, cusparseSpMatDescr_t& matA, void*& dBuffer) {
    cusparseDestroySpMat(matA);
    cusparseDestroy(handle);
    cudaFree(dBuffer);
    dBuffer = nullptr;
}

void kkh_cuspmv(double* d_b, cusparseSpMatDescr_t& matA, double* d_x, cusparseHandle_t& handle, void* dBuffer, int N) {
    double alpha = 1.0f, beta = 0.0f;
    cusparseDnVecDescr_t vecX, vecB;
    cusparseCreateDnVec(&vecX, N, d_x, CUDA_R_64F);
    cusparseCreateDnVec(&vecB, N, d_b, CUDA_R_64F);

    // [cuSPARSE] CSR SpMV: d_b = matA * d_x.
    cusparseSpMV(handle, CUSPARSE_OPERATION_NON_TRANSPOSE,
                 &alpha, matA, vecX, &beta, vecB,
                 CUDA_R_64F, CUSPARSE_SPMV_CSR_ALG1, dBuffer);

    cusparseDestroyDnVec(vecX);
    cusparseDestroyDnVec(vecB);
}

void kkh_cuspsv_init(cusparseHandle_t& handleL, cusparseSpMatDescr_t& matL, void*& dBufferL, cusparseSpSVDescr_t& spsvDescrL,
                     cusparseFillMode_t fill, cusparseDiagType_t diag,
                     int* d_L_Rowindx, int* d_L_Rowpnt, int* d_L_Colindx, double* d_L_val,
                     double* d_Ux, double* d_b, int NNZ_L, int N) {

    size_t bufferSize = 0;
    double alpha = 1.0;

    // [cuSPARSE] Build triangular CSR descriptor and SpSV analysis object.
    cusparseCreate(&handleL);

    cusparseCreateCsr(&matL, N, N, NNZ_L,
                      d_L_Rowpnt, d_L_Colindx, d_L_val,
                      CUSPARSE_INDEX_32I, CUSPARSE_INDEX_32I,
                      CUSPARSE_INDEX_BASE_ZERO, CUDA_R_64F);

    cusparseDnVecDescr_t vecX, vecB;
    cusparseCreateDnVec(&vecX, N, d_Ux, CUDA_R_64F);
    cusparseCreateDnVec(&vecB, N, d_b , CUDA_R_64F);


    // set matrix as upper triangular
    // cusparseFillMode_t fill = CUSPARSE_FILL_MODE_UPPER;
    // cusparseDiagType_t diag = CUSPARSE_DIAG_TYPE_NON_UNIT;
    
    cusparseSpMatSetAttribute(matL, CUSPARSE_SPMAT_FILL_MODE, &fill, sizeof(fill));
    cusparseSpMatSetAttribute(matL, CUSPARSE_SPMAT_DIAG_TYPE, &diag, sizeof(diag));

    cusparseSpSV_createDescr(&spsvDescrL);

    // [cuSPARSE] SpSV workspace and symbolic analysis for L/U solve.
    cusparseSpSV_bufferSize(handleL,CUSPARSE_OPERATION_NON_TRANSPOSE,
                            &alpha,matL,vecB,vecX,
                            CUDA_R_64F,CUSPARSE_SPSV_ALG_DEFAULT,spsvDescrL,&bufferSize);
    cudaMalloc(&dBufferL, bufferSize);

    cusparseSpSV_analysis(  handleL,CUSPARSE_OPERATION_NON_TRANSPOSE,
                            &alpha,matL,vecB,vecX,
                            CUDA_R_64F,CUSPARSE_SPSV_ALG_DEFAULT,spsvDescrL,dBufferL);

    cusparseDestroyDnVec(vecX);
    cusparseDestroyDnVec(vecB);
}

void kkh_cuspsv_clean(cusparseHandle_t& handleL, cusparseSpMatDescr_t& matL, void*& dBufferL, cusparseSpSVDescr_t& spsvDescrL) {
    cusparseDestroySpMat(matL);
    cusparseDestroy(handleL);
    cudaFree(dBufferL);
    dBufferL = nullptr;
    cusparseSpSV_destroyDescr(spsvDescrL);
}

void kkh_cuspsv(double* d_Ux, cusparseSpMatDescr_t& matL, double* d_b, cusparseHandle_t& handleL, void*& dBufferL,cusparseSpSVDescr_t& spsvDescrL, int N) {
    double alpha = 1.0;
nvtxRangePushA("--alloc");
    cusparseDnVecDescr_t vecX, vecB;
    cusparseCreateDnVec(&vecB, N, d_b , CUDA_R_64F);
    cusparseCreateDnVec(&vecX, N, d_Ux, CUDA_R_64F);
nvtxRangePop();

nvtxRangePushA("--solve");
    // [cuSPARSE] SpSV triangular solve: d_Ux = matL^{-1} * d_b.
    cusparseSpSV_solve( handleL,CUSPARSE_OPERATION_NON_TRANSPOSE,
                        &alpha,matL,vecB,vecX,
                        CUDA_R_64F,CUSPARSE_SPSV_ALG_DEFAULT,spsvDescrL);
nvtxRangePop();

nvtxRangePushA("--dealloc");
    cusparseDestroyDnVec(vecX);
    cusparseDestroyDnVec(vecB);
nvtxRangePop();
}

__global__ void kkh_cuvecmul(double *c, double *a,  double *b,  int n)
{
    // [CUDA Kernel] One thread handles one vector element: c[i] = a[i] * b[i].
    int idx = threadIdx.x + blockDim.x * blockIdx.x;
    if (idx < n) {
        c[idx] = a[idx] * b[idx];
    }
}
__global__ void kkh_cuvecadd(double *c, double *a,  double *b,  int n, double alpha)
{
    // [CUDA Kernel] One thread handles one vector element: c[i] = a[i] + alpha*b[i].
    int idx = threadIdx.x + blockDim.x * blockIdx.x;
    if (idx < n) {
        c[idx] = a[idx] + alpha* b[idx];
    }
}
__global__ void kkh_cuinvdiagA(double *c, int* d_A_Rowpnt, int* d_A_Colindx, double* d_A_val,  int n,  int m)
{
    // [CUDA Kernel] One row per thread; scan CSR row to extract inverse diagonal.
    int idx = threadIdx.x + blockDim.x * blockIdx.x;
    if (idx < n) {
        int row_start = d_A_Rowpnt[idx];
        int row_end = d_A_Rowpnt[idx + 1];
        for (int j = row_start; j < row_end; j++) {
            if (d_A_Colindx[j] == idx) {
                c[idx] = 1.0/d_A_val[j];
                return;
            }
        }
        c[idx] = 0.0; // If no diagonal entry found, set to zero
    }
}

__global__ void kkh_cuscalar_div(double *result, double *mresult, double* d_A, double* d_B)
{
    // [CUDA Kernel] Single-thread scalar division kept on device.
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        (*result) = (*d_A)/(*d_B);
        (*mresult) = -(*result);
        return;
    }
}
__global__ void kkh_cuscalar_divmul(double *result, double* d_A1, double* d_A2, double* d_B1, double* d_B2)
{
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        (*result) = ((*d_A1)/(*d_A2))*((*d_B1)/(*d_B2));
        return;
    }
}
__global__ void kkh_cuvecadd_device(double *c, double *a,  double *b,  int n, double *alpha)
{
    // [CUDA Kernel] One thread per vector element; alpha is a device scalar.
    int idx = threadIdx.x + blockDim.x * blockIdx.x;
    if (idx < n) {
        c[idx] = a[idx] + (*alpha) * b[idx];
    }
}
__global__ void kkh_cucheck(double *rr1, double *rr0sq, double epssq, bool *d_flag)
{
    // [CUDA Kernel] Single-thread convergence check using device residuals.
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        if ((*rr1)/(*rr0sq) < (epssq)) {
            *d_flag = true; // Set flag to true if condition is met
        } else {
            *d_flag = false; // Otherwise, set it to false
        }
    }
}
__global__ void kkh_cuscalar_copy(double *a, double *b)
{
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        *a = *b; // Copy value from b to a
    }
}

__global__ void kkh_cuvecadd_stride_device(double *c, double *a,  double *b,  int n, int stride, double *alpha)
{
    int idx = threadIdx.x + blockDim.x * blockIdx.x;
    double alpha_val = *alpha;
    int ia,ib;
    ia = idx * stride;
    ib = ia + stride;
    if(ib> n) {
        ib = n;
    }
    for (int i = ia; i < ib; i++)
    {
        c[i] = a[i] + alpha_val * b[i];
    }
}
__global__ void kkh_cuvecadd_ilp_device(double *c, const double *a, const double *b, int n, double *alpha)
{
    // [CUDA Kernel] Grid-stride vector update for larger vector ranges.
    int idx = threadIdx.x + blockDim.x * blockIdx.x;
    int stride = blockDim.x * gridDim.x;
    double alpha_val = *alpha;

    for (int i = idx; i < n; i += stride) {
        c[i] = a[i] + alpha_val * b[i];
    }
}


void kkh_cuspsv_init2(cusparseHandle_t& handleL, cusparseSpMatDescr_t& matL, void*& dBufferL, cusparseSpSVDescr_t& spsvDescrL,
                     cusparseFillMode_t fill, cusparseDiagType_t diag,
                     int* d_L_Rowpnt, int* d_L_Colindx, double* d_L_val,
                     double* d_Ux, double* d_b, int NNZ_L, int N) {

    size_t bufferSize = 0;
    double alpha = 1.0;

    // [cuSPARSE] Alternate SpSV initialization used by the iLU path.
    cusparseCreate(&handleL);

    cusparseCreateCsr(&matL, N, N, NNZ_L,
                      d_L_Rowpnt, d_L_Colindx, d_L_val,
                      CUSPARSE_INDEX_32I, CUSPARSE_INDEX_32I,
                      CUSPARSE_INDEX_BASE_ZERO, CUDA_R_64F);

    cusparseDnVecDescr_t vecX, vecB;
    cusparseCreateDnVec(&vecX, N, d_Ux, CUDA_R_64F);
    cusparseCreateDnVec(&vecB, N, d_b , CUDA_R_64F);


    // set matrix as upper triangular
    // cusparseFillMode_t fill = CUSPARSE_FILL_MODE_UPPER;
    // cusparseDiagType_t diag = CUSPARSE_DIAG_TYPE_NON_UNIT;
    
    cusparseSpMatSetAttribute(matL, CUSPARSE_SPMAT_FILL_MODE, &fill, sizeof(fill));
    cusparseSpMatSetAttribute(matL, CUSPARSE_SPMAT_DIAG_TYPE, &diag, sizeof(diag));

    cusparseSpSV_createDescr(&spsvDescrL);

    // [cuSPARSE] SpSV workspace and analysis for reusable triangular solves.
    cusparseSpSV_bufferSize(handleL,CUSPARSE_OPERATION_NON_TRANSPOSE,
                            &alpha,matL,vecB,vecX,
                            CUDA_R_64F,CUSPARSE_SPSV_ALG_DEFAULT,spsvDescrL,&bufferSize);
    cudaMalloc(&dBufferL, bufferSize);

    cusparseSpSV_analysis(  handleL,CUSPARSE_OPERATION_NON_TRANSPOSE,
                            &alpha,matL,vecB,vecX,
                            CUDA_R_64F,CUSPARSE_SPSV_ALG_DEFAULT,spsvDescrL,dBufferL);

    cusparseDestroyDnVec(vecX);
    cusparseDestroyDnVec(vecB);
}
// kkh_cuvecadd_device<<<blocksPerGrid, threadsPerBlock>>>(x, x, y, n,  alpha);// x     = x + alpha*y
// kkh_cuvecadd_stride_device<<<blocks_stride,threads_stride>>>(x, x, y, n, stride,  alpha);// x     = x + alpha*y
// kkh_cuvecadd_ilp_device<<<blocks_stride,threads_stride>>>(x, x, y, n,  alpha);// x     = x + alpha*y
