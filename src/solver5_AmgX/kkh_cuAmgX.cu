/*
 * AmgX one-shot solve core path.
 * Role: demonstrate AmgX resource/config creation, CSR matrix upload, solver
 * setup, solve, and download for a single AMG/Krylov solve.
 * Uses: AmgX C API and CUDA device pointers supplied by the common ABI.
 */
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <cstring>
#include <cuda_runtime.h>
#include <amgx_c.h>   // AMGX C API
#include "kkh_cuAmgX.h"

#include <nvtx3/nvToolsExt.h>

void kkh_cuAmgX(int n, int nnz,
                const int *d_rowPtr,
                const int *d_colInd,
                const double *d_val,
                double *d_vec)
{
    // [AmgX] Initialize library, config, resources, matrix, and vectors.
    AMGX_initialize();

    AMGX_config_handle      cfg;
    AMGX_resources_handle   rsrc;
    AMGX_matrix_handle      Amatrix;
    AMGX_vector_handle      rhs, sol;

    AMGX_config_create_from_file(&cfg, "amgx_config.json");
    AMGX_resources_create_simple(&rsrc, cfg);
    AMGX_matrix_create(&Amatrix, rsrc, AMGX_mode_dDDI);
    AMGX_vector_create(&rhs, rsrc, AMGX_mode_dDDI);
    AMGX_vector_create(&sol, rsrc, AMGX_mode_dDDI);

    // [AmgX] Upload CSR matrix and RHS directly from CUDA device pointers.
    AMGX_matrix_upload_all(Amatrix, n, nnz, 1, 1, d_rowPtr, d_colInd, d_val, NULL);
    AMGX_vector_upload(rhs, n, 1, d_vec);
    AMGX_vector_set_zero(sol, n, 1);

    AMGX_solver_handle solver;

    AMGX_solver_create(&solver, rsrc, AMGX_mode_dDDI, cfg);

    AMGX_solver_setup(solver, Amatrix);     // [AmgX] setup includes AMG hierarchy.
    AMGX_solver_solve(solver, rhs, sol);    // [AmgX] solve phase.
    AMGX_vector_download(sol, d_vec);       // [AmgX] write solution back to d_vec.

    // cudaDeviceSynchronize();

    // AMGX_matrix_replace_coefficients(Amatrix, n, nnz, d_val, NULL);
    // AMGX_solver_setup(solver, Amatrix);
    // AMGX_solver_solve(solver, rhs, sol);
    // AMGX_vector_download(sol, d_vec);

    // 정리
    AMGX_solver_destroy(solver);
    AMGX_vector_destroy(sol);
    AMGX_vector_destroy(rhs);
    AMGX_matrix_destroy(Amatrix);
    AMGX_resources_destroy(rsrc);
    AMGX_config_destroy(cfg);

    AMGX_finalize();
}
