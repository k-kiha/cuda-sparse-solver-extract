/*
 * Optional iLU(0) preconditioned CUDA solver.
 * Role: show iLU(0) factorization feeding cuSPARSE SpSV lower/upper triangular
 * solves inside a BiCGStab iteration.
 * Uses: CUDA Runtime workspaces, cuSPARSE SpMV, cuSPARSE SpSV, cuBLAS Ddot,
 * custom CUDA kernels, and NVTX profiling ranges.
 */
#include <stdio.h>
#include <math.h>
#include <cuda_runtime.h>
#include <cusparse.h>
#include <cublas_v2.h>

#include "../kkh_cudatools/kkh_cudatools.h"
#include "../kkh_cudatools/kkh_iLU_cpu.h"

#include <nvtx3/nvToolsExt.h>

#include <stdlib.h>

extern "C" {
void kkh_cuiLUbicg(int n, int m, int *A_ipnt, int *A_jinx, double *A_val, double *x)
{

    /*/****** for plot ********
        double *bhat_d, *rhs, *bhat_h;
        char fname[64];
        cudaMalloc((void**)&bhat_d, n * sizeof(double));// for plot
        cudaMallocHost((void**)&rhs, n * sizeof(double));// for plot
        cudaMallocHost((void**)&bhat_h, n * sizeof(double));// for plot
        cudaMemcpy(rhs, x, n * sizeof(double), cudaMemcpyDeviceToHost);
    //****** for plot ********/

    // NEW: split to separate CSR for L and U
    int nnzL = 0, nnzU = 0;
    int *L_rpnt,*L_cinx;
    int *U_rpnt,*U_cinx;
    double *L_val,*U_val;

    // [NVTX] iLU(0) factorization and L/U CSR upload setup.
    nvtxRangePushA("::int_precond::");
    // [CUDA Runtime] Downloads device CSR, computes CPU iLU(0), uploads L/U CSR.
    kkh_iLU_cpu_ilu0(n, m, A_ipnt, A_jinx, A_val,
                     &L_rpnt, &L_cinx, &L_val,
                     &U_rpnt, &U_cinx, &U_val,
                     &nnzL, &nnzU);
    nvtxRangePop();

    //-- cuSPMV::init ---- {{{
    double *Ux;
    // [CUDA Runtime] Intermediate vector for lower then upper triangular solves.
    cudaMalloc(&Ux, sizeof(double) * n);

    void *dBufferL = nullptr, *dBufferU = nullptr;
    cusparseHandle_t     handleL, handleU;
    cusparseSpMatDescr_t matL, matU;
    cusparseSpSVDescr_t  spsvDescrL, spsvDescrU;

    // [cuSPARSE] SpSV analysis for lower triangular L solve.
    kkh_cuspsv_init2( handleL, matL, dBufferL, spsvDescrL
                    , CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_UNIT    
                    , L_rpnt, L_cinx, L_val, Ux, x , nnzL, n );

    // [cuSPARSE] SpSV analysis for upper triangular U solve.
    kkh_cuspsv_init2( handleU, matU, dBufferU, spsvDescrU
                    , CUSPARSE_FILL_MODE_UPPER, CUSPARSE_DIAG_TYPE_NON_UNIT
                    , U_rpnt, U_cinx, U_val, Ux, x , nnzU, n );
    //-- cuSPMV::init ---- }}}
    
    
    double eps = 5e-8;
    double epssq= eps*eps;
    int maxiter = 10000;

    double *r,*rhat,*p,*h,*s,*t,*v,*Ax;
    double *invdiagA;
    double *y,*z;
    double *alpha, *beta, *rho_a, *rho_b, *omega,  *rr0sq;
    double *malpha,*momega;
    double *rr1,*rr1_a, *rr2;
    bool *d_flag,*h_flag;
    double tmpA,tmpB,tmpC;

    int iter;

    cusparseSpMatDescr_t matA;
    cusparseHandle_t     handle_spmv;
    cublasHandle_t       handle_dotp;

    void                 *dBuffer = nullptr;

    int threadsPerBlock = 128;
    int blocksPerGrid   = (n + threadsPerBlock - 1) / threadsPerBlock;

    printf("kkh_cuiLUbicg :: iLU precond. BiCGStab :: with eps=%e, maxiter=%d\n", eps, maxiter);

    // [CUDA Runtime] Allocate Krylov vectors and device scalar workspaces.
    cudaMalloc((void**)&r   , n * sizeof(double));
    cudaMalloc((void**)&rhat, n * sizeof(double));
    cudaMalloc((void**)&p   , n * sizeof(double));
    cudaMalloc((void**)&h   , n * sizeof(double));
    cudaMalloc((void**)&s   , n * sizeof(double));
    cudaMalloc((void**)&t   , n * sizeof(double));
    cudaMalloc((void**)&v   , n * sizeof(double));
    cudaMalloc((void**)&Ax  , n * sizeof(double));
    
    cudaMalloc((void**)&invdiagA, n * sizeof(double));
    cudaMalloc((void**)&y   , n * sizeof(double));
    cudaMalloc((void**)&z   , n * sizeof(double));

    cudaMalloc((void**)&alpha, sizeof(double));
    cudaMalloc((void**)&beta , sizeof(double));
    cudaMalloc((void**)&rho_a, sizeof(double));
    cudaMalloc((void**)&rho_b, sizeof(double));
    cudaMalloc((void**)&omega, sizeof(double));
    cudaMalloc((void**)&rr0sq, sizeof(double));
    cudaMalloc((void**)&rr1  , sizeof(double));
    cudaMalloc((void**)&rr1_a, sizeof(double));
    cudaMalloc((void**)&rr2  , sizeof(double));
    cudaMalloc((void**)&malpha, sizeof(double));
    cudaMalloc((void**)&momega, sizeof(double));
    cudaMalloc((void**)&d_flag, sizeof(bool));
    cudaMallocHost((void**)&h_flag, sizeof(bool));  // pinned memory

    cudaMemset(r   , 0, n * sizeof(double));
    cudaMemset(rhat, 0, n * sizeof(double));
    cudaMemset(p   , 0, n * sizeof(double));
    cudaMemset(h   , 0, n * sizeof(double));
    cudaMemset(s   , 0, n * sizeof(double));
    cudaMemset(t   , 0, n * sizeof(double));
    cudaMemset(v   , 0, n * sizeof(double));
    cudaMemset(Ax  , 0, n * sizeof(double));

    // [CUDA Kernel] Diagonal extraction remains available for comparison.
    kkh_cuinvdiagA<<<blocksPerGrid, threadsPerBlock>>>(invdiagA, A_ipnt, A_jinx, A_val, n, m);
    cudaMemset(y   , 0, n * sizeof(double));
    cudaMemset(z   , 0, n * sizeof(double));    

    *h_flag = false;
    cudaMemcpy(d_flag, h_flag, sizeof(bool), cudaMemcpyHostToDevice);

    // [cuSPARSE] Prepare reusable CSR SpMV descriptor and workspace.
    kkh_cuspmv_init(handle_spmv, matA, dBuffer, A_ipnt, A_jinx, A_val, x, Ax, m, n);
    // [cuBLAS] Dot products remain on device pointer mode.
    cublasCreate(&handle_dotp);

    cublasSetPointerMode(handle_dotp, CUBLAS_POINTER_MODE_DEVICE);

    nvtxRangePushA("--solver--");
    // ~~~    
    kkh_cuspmv(Ax, matA, x, handle_spmv, dBuffer, n);                                   // [cuSPARSE] CSR SpMV: Ax = A * x
    kkh_cuvecadd<<<blocksPerGrid, threadsPerBlock>>>(r, x, Ax, n, -1.0);                // r     = x - Ax
    cudaMemcpy(rhat , r, n * sizeof(double), cudaMemcpyDeviceToDevice);                 // rhat  = r
    cublasDdot(handle_dotp, n, r, 1, r, 1, rho_a);                                      // [cuBLAS] rho_a = r^T * r
    cudaMemcpy(p    , r, n * sizeof(double), cudaMemcpyDeviceToDevice);                 // p     = r
    kkh_cuscalar_copy<<<1, 1>>>(rr0sq, rho_a);

    for (iter = 0; iter < maxiter; iter++)
    {
        nvtxRangePushA("loop");

        nvtxRangePushA("::precond::");
        // kkh_cuvecmul<<<blocksPerGrid, threadsPerBlock>>>(y, invdiagA, p, n);            // y     = invM * p
        kkh_cuspsv(Ux, matL, p , handleL, dBufferL, spsvDescrL, n);                    // [cuSPARSE] SpSV L solve
        kkh_cuspsv(y , matU, Ux, handleU, dBufferU, spsvDescrU, n);                    // [cuSPARSE] SpSV U solve
        nvtxRangePop();        
        nvtxRangePushA("::Mmul::");
        kkh_cuspmv(v, matA, y, handle_spmv, dBuffer, n);                                // [cuSPARSE] v = A * y
        nvtxRangePop();       

        nvtxRangePushA("::innerp::");
        cublasDdot(handle_dotp, n, rhat, 1, v, 1, rr1);                                 // [cuBLAS] rr1 = rhat^T * v
        kkh_cuscalar_div<<<1, 1>>>(alpha,malpha,rho_a,rr1);                             // alpha = rho_a / rr1
        nvtxRangePop();
        nvtxRangePushA("::proj::");
        kkh_cuvecadd_device<<<blocksPerGrid, threadsPerBlock>>>(x, x, y, n,  alpha);    // [CUDA Kernel] x = x + alpha*y
        kkh_cuvecadd_device<<<blocksPerGrid, threadsPerBlock>>>(s, r, v, n, malpha);    // s     = r - alpha*v
        nvtxRangePop();

        cublasDdot(handle_dotp, n, s, 1, s, 1, rr1_a);                                  // [cuBLAS] rr1_a = s^T * s
        kkh_cucheck<<<1, 1>>>(rr1_a,rr0sq,epssq,d_flag);                                // rr1_a/rr0sq < epssq
        cudaMemcpy(h_flag, d_flag, sizeof(bool), cudaMemcpyDeviceToHost);

        if(*h_flag) {
            /*/****** for plot ********
            {
                kkh_cuspmv(bhat_d, matA, x, handle_spmv, dBuffer, n);                       // for plot: bhat_d= A * x
                cudaMemcpy(bhat_h, bhat_d, n * sizeof(double), cudaMemcpyDeviceToHost);     // for plot

                // 파일 이름 구성: residual_****_0000.txt
                sprintf(fname, "residual_%04d_0000.txt", iter);  // 4자리 iteration 번호 사용

                FILE *fp = fopen(fname, "w");
                double val = 0.0;
                if (fp != NULL) {
                    for (int i = 0; i < n; i++) {
                        val = bhat_h[i];
                        if (rhs[i] != 0.0)
                            val = fabs((bhat_h[i] - rhs[i]) / rhs[i]);
                        fprintf(fp, "%e\n", val);
                    }
                    fclose(fp);
                } else {
                    printf("Warning: cannot open file %s for writing\n", fname);
                }
            }
            //****** for plot ********/

            cudaMemcpy(&tmpA, rr1_a, sizeof(double), cudaMemcpyDeviceToHost);
            cudaMemcpy(&tmpC, rr0sq, sizeof(double), cudaMemcpyDeviceToHost);
            printf("Converged at iteration %d: rr1_a = %30.20e\n", iter, sqrt(tmpA/tmpC));
            nvtxRangePop();
            break;
        }

        nvtxRangePushA("::precond::");
        // kkh_cuvecmul<<<blocksPerGrid, threadsPerBlock>>>(z, invdiagA, s, n);            // z     = invM * s
        kkh_cuspsv(Ux, matL, s , handleL, dBufferL, spsvDescrL, n);                    // [cuSPARSE] SpSV L solve
        kkh_cuspsv(z , matU, Ux, handleU, dBufferU, spsvDescrU, n);                    // [cuSPARSE] SpSV U solve
        nvtxRangePop();        
        nvtxRangePushA("::Mmul::");
        kkh_cuspmv(t, matA, z, handle_spmv, dBuffer, n);                                // [cuSPARSE] t = A * z       
        nvtxRangePop(); 

        nvtxRangePushA("::innerp::");
        cublasDdot(handle_dotp, n, t, 1, s, 1,  rr1);                                   // [cuBLAS] rr1 = t^T * s
        cublasDdot(handle_dotp, n, t, 1, t, 1,  rr2);                                   // [cuBLAS] rr2 = t^T * t
        kkh_cuscalar_div<<<1, 1>>>(omega,momega,rr1,rr2);                               // omega = rr1 / rr2
        nvtxRangePop();
        nvtxRangePushA("::proj::");
        kkh_cuvecadd_device<<<blocksPerGrid, threadsPerBlock>>>(x, x, z, n,  omega);    // x     = x + omega*z
        kkh_cuvecadd_device<<<blocksPerGrid, threadsPerBlock>>>(r, s, t, n, momega);    // r     = s - omega*t
        nvtxRangePop();

        /*/****** for plot ********
        {
            kkh_cuspmv(bhat_d, matA, x, handle_spmv, dBuffer, n);                       // for plot: bhat_d= A * x
            cudaMemcpy(bhat_h, bhat_d, n * sizeof(double), cudaMemcpyDeviceToHost);     // for plot

            // 파일 이름 구성: residual_****_0000.txt
            sprintf(fname, "residual_%04d_0000.txt", iter);  // 4자리 iteration 번호 사용

            FILE *fp = fopen(fname, "w");
            double val = 0.0;
            if (fp != NULL) {
                for (int i = 0; i < n; i++) {
                    val = bhat_h[i];
                    if (rhs[i] != 0.0)
                        val = fabs((bhat_h[i] - rhs[i]) / rhs[i]);
                    fprintf(fp, "%e\n", val);
                }
                fclose(fp);
            } else {
                printf("Warning: cannot open file %s for writing\n", fname);
            }
        }
        //****** for plot ********/
        
        nvtxRangePushA("::innerp::");
        cublasDdot(handle_dotp, n, r, 1, r, 1,  rr1);                                   // [cuBLAS] rr1 = r^T * r
        kkh_cucheck<<<1, 1>>>(rr1,rr0sq,epssq,d_flag);                                  // rr1/rr0sq < epssq
        nvtxRangePop();
        cudaMemcpy(h_flag, d_flag, sizeof(bool), cudaMemcpyDeviceToHost);
        
        if (iter % 100 == 0) {
            cudaMemcpy(&tmpA, rr1_a, sizeof(double), cudaMemcpyDeviceToHost);
            cudaMemcpy(&tmpB, rr1  , sizeof(double), cudaMemcpyDeviceToHost);
            cudaMemcpy(&tmpC, rr0sq, sizeof(double), cudaMemcpyDeviceToHost);
            printf("Iteration %d: rr = %30.20e,%30.20e\n", iter, sqrt(tmpA/tmpC), sqrt(tmpB/tmpC));
        }
        if(*h_flag) {
            cudaMemcpy(&tmpB, rr1  , sizeof(double), cudaMemcpyDeviceToHost);
            cudaMemcpy(&tmpC, rr0sq, sizeof(double), cudaMemcpyDeviceToHost);
            printf("Converged at iteration %d: rr1.  = %30.20e\n", iter, sqrt(tmpB/tmpC));
            nvtxRangePop();
            break;
        }

        nvtxRangePushA("::innerp::");
        cublasDdot(handle_dotp, n, rhat, 1, r, 1, rho_b);                               // [cuBLAS] rho_b = rhat^T * r

        kkh_cuscalar_divmul<<<1, 1>>>(beta,rho_b,rho_a,alpha,omega);                    // beta  = (rho_b/rho_a)*(alpha/omega)
        nvtxRangePop();
        nvtxRangePushA("::proj::");
        kkh_cuvecadd_device<<<blocksPerGrid, threadsPerBlock>>>(p, p, v, n, momega);    // p     = p - omega*v
        kkh_cuvecadd_device<<<blocksPerGrid, threadsPerBlock>>>(p, r, p, n,   beta);    // p     = r + beta*p
        nvtxRangePop();
        
        kkh_cuscalar_copy<<<1, 1>>>(rho_a, rho_b);
        nvtxRangePop();

    }
    nvtxRangePop();

    // ~~~    
    kkh_cuspmv_clean(handle_spmv, matA, dBuffer);
    cublasDestroy(handle_dotp);

    cudaFree(r   );
    cudaFree(rhat);
    cudaFree(p   );
    cudaFree(h   );
    cudaFree(s   );
    cudaFree(t   );
    cudaFree(v   );
    cudaFree(Ax  );

    cudaFree(invdiagA);
    cudaFree(y   );
    cudaFree(z   );

    cudaFree(alpha);  
    cudaFree(beta );  
    cudaFree(rho_a);  
    cudaFree(rho_b);  
    cudaFree(omega);  
    cudaFree(rr0sq);  
    cudaFree(rr1  );  
    cudaFree(rr1_a);  
    cudaFree(rr2  );  
    cudaFree(malpha);  
    cudaFree(momega);  
    cudaFree(d_flag);
    cudaFreeHost(h_flag);

    kkh_cuspsv_clean(handleL, matL, dBufferL, spsvDescrL);
    kkh_cuspsv_clean(handleU, matU, dBufferU, spsvDescrU);

    cudaFree(L_rpnt);
    cudaFree(L_cinx);
    cudaFree(L_val );
    cudaFree(U_rpnt);
    cudaFree(U_cinx);
    cudaFree(U_val );
    cudaFree(Ux);


    /*/****** for plot ********
        cudaFree(bhat_d);// for plot
        cudaFreeHost(rhs);// for plot
        cudaFreeHost(bhat_h);// for plot
    //****** for plot ********/


    printf("OK!\n");
}
}
