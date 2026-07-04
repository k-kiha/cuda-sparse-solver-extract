/*
 * CUDA solver ABI entrypoint.
 * Role: expose one C ABI for Fortran/C callers and dispatch to the selected
 * CUDA solver path.
 * Uses: CUDA Runtime synchronization; default cuSPARSE/cuBLAS solver dispatch;
 * cuSPARSE SpSV+iLU(0) and AmgX dispatch.
 */
#include <stdio.h>
#include <cuda_runtime.h>
#include <cusparse.h>
#include <cublas_v2.h>

#if defined(KISTI_SOLVER_ILU)
#include "./solver7_iLU/kkh_cuiLUbicg.h"
#elif defined(KISTI_SOLVER_AMGX)
#include "./solver6_AmgX_recycle/kkh_cuAmgX.h"
#else
#include "./solver3_diagbicg/kkh_cudiagbicg.h"
#endif

extern "C" {
void kisti_solver_c(int n, int m, int *d_rowPtr, int *d_colInd, double *d_val, double *d_vec)
{
#if defined(KISTI_SOLVER_ILU)
    printf("KISTI CUDA solver: ILU(0) + cuSPARSE SpSV BiCGStab, n=%d, nnz=%d\n", n, m);
#elif defined(KISTI_SOLVER_AMGX)
    printf("KISTI CUDA solver: AmgX AMG/GMRES path, n=%d, nnz=%d\n", n, m);
#else
    printf("KISTI CUDA solver: diagonal-preconditioned cuSPARSE/cuBLAS BiCGStab, n=%d, nnz=%d\n", n, m);
#endif

    // [CUDA Runtime] Synchronize at the ABI boundary before solver dispatch.
    cudaDeviceSynchronize();

#if defined(KISTI_SOLVER_ILU)
    // [cuSPARSE SpSV + iLU(0)] Triangular-solve preconditioned core path.
    kkh_cuiLUbicg(n, m, d_rowPtr, d_colInd, d_val, d_vec);
#elif defined(KISTI_SOLVER_AMGX)
    // [AmgX] AMG/GMRES setup, solve, and reuse core path.
    kkh_cuAmgX(n, m, d_rowPtr, d_colInd, d_val, d_vec);
#else
    // [cuSPARSE] CSR SpMV + [cuBLAS] dot based default BiCGStab path.
    kkh_cudiagbicg(n, m, d_rowPtr, d_colInd, d_val, d_vec);
#endif

    // [CUDA Runtime] Ensure solver work is visible before returning to caller.
    cudaDeviceSynchronize();
}
}
