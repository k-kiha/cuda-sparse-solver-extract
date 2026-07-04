/*
 * Minimal CUDA solver skeleton.
 * Role: show how a new solver can reuse the same ABI style with cuSPARSE SpMV,
 * cuBLAS Ddot, CUDA Runtime workspaces, and simple custom kernels.
 */
#include <stdio.h>
#include <math.h>
#include <cuda_runtime.h>
#include <cusparse.h>
#include <cublas_v2.h>

#include "kkh_tool1.h"

extern "C" {
void EXAMPLE_solver(int n, int m, int *A_ipnt, int *A_jinx, double *A_val, double *x)
{
    double eps = 1e-10;
    int maxiter = 10000;

    double *r,*p,*Ax;
    double alpha, beta, rho_a, rho_b, tmp;

    cusparseHandle_t Hcuspars = NULL;
    cublasHandle_t   Hcublas = NULL;
    cusparseSpMatDescr_t matA;
    void *dBuffer = NULL;

    int threadsPerBlock = 256;
    int blocksPerGrid = (n + threadsPerBlock - 1) / threadsPerBlock;

    printf("EXAMPLE_solver :: CG :: with eps=%e, maxiter=%d\n", eps, maxiter);
    
    // [CUDA Runtime] Allocate small CG workspace vectors.
    cudaMalloc((void**)&r , n * sizeof(double));
    cudaMalloc((void**)&p , n * sizeof(double));
    cudaMalloc((void**)&Ax, n * sizeof(double));

    cudaMemset(r , 0, n * sizeof(double));
    cudaMemset(p , 0, n * sizeof(double));
    cudaMemset(Ax, 0, n * sizeof(double));

    cublasCreate(&Hcublas); // [cuBLAS] Ddot handle.
    kkh_tool1_cusparse_init(n, n, A_ipnt, A_jinx, A_val, x, &matA, &Hcuspars, &dBuffer, Ax); // [cuSPARSE] CSR SpMV setup.

    //~~~~
    kkh_tool1_cusparse(matA, Hcuspars, dBuffer, n, n, x, Ax); // [cuSPARSE] Ax = A*x.
    kkh_tool1_vec_add<<<blocksPerGrid, threadsPerBlock>>>(x, Ax, r, n, -1.0);
    cudaMemcpy(p, r, n * sizeof(double), cudaMemcpyDeviceToDevice);

    cublasDdot(Hcublas, n, r, 1, r, 1, &rho_a); // [cuBLAS] rho_a = r^T*r.

    for (int iter = 0; iter < maxiter; iter++)
    {
        kkh_tool1_cusparse(matA, Hcuspars, dBuffer, n, n, p, Ax); // [cuSPARSE] Ax = A*p.

        cublasDdot(Hcublas, n, p, 1, Ax, 1, &tmp); // [cuBLAS] p^T*A*p.
        alpha = rho_a / tmp;        
        kkh_tool1_vec_add<<<blocksPerGrid, threadsPerBlock>>>(x, p, x, n, alpha);
        kkh_tool1_vec_add<<<blocksPerGrid, threadsPerBlock>>>(r,Ax, r, n,-alpha);

        cublasDdot(Hcublas, n, r, 1, r, 1, &rho_b); // [cuBLAS] residual norm.
        if (sqrt(rho_b) < eps) {
            printf("Converged at iteration %d: rho = %30.20e\n", iter, sqrt(rho_b));
            break;
        }
        beta = rho_b/rho_a;
        kkh_tool1_vec_add<<<blocksPerGrid, threadsPerBlock>>>(r, p, p, n, beta);
        rho_a = rho_b;
        if (iter%100 == 0) printf("Iteration %d: rho = %30.20e\n", iter, sqrt(rho_b));
    }
    //~~~~
    cublasDestroy(Hcublas);
    kkh_tool1_cusparse_finish(matA, Hcuspars, dBuffer);
    cudaFree(r );
    cudaFree(p );
    cudaFree(Ax);
}
}
