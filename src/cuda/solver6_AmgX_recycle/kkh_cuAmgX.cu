/*
 * AmgX coefficient-reuse core path.
 * Role: demonstrate initial AmgX setup/solve, coefficient replacement, and a
 * later solve that can reuse an existing solver object.
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
    // [AmgX] Initialize library, config, resources, matrix, solver, and vectors.
    AMGX_initialize();

    AMGX_config_handle      cfg;    //<<***!!!
    AMGX_resources_handle   rsrc;   //<<***!!!
    AMGX_matrix_handle      Amatrix;//<<***!!!
    AMGX_solver_handle      solver; //<<***!!!
    AMGX_vector_handle      rhs, sol;


    //::: solver 1:::::::::::
    AMGX_config_create_from_file(&cfg, "amgx_config.json"); // [AmgX] JSON solver configuration.
    AMGX_resources_create_simple(&rsrc, cfg);               //<<***!!!
    AMGX_matrix_create(&Amatrix, rsrc, AMGX_mode_dDDI);     //<<***!!!
    AMGX_vector_create(&rhs, rsrc, AMGX_mode_dDDI);
    AMGX_vector_create(&sol, rsrc, AMGX_mode_dDDI);

    // [AmgX] Initial CSR upload from CUDA device pointers.
    AMGX_matrix_upload_all(Amatrix, n, nnz, 1, 1, d_rowPtr, d_colInd, d_val, NULL);
    AMGX_vector_upload(rhs, n, 1, d_vec);
    AMGX_vector_set_zero(sol, n, 1);

    AMGX_solver_create(&solver, rsrc, AMGX_mode_dDDI, cfg);
    AMGX_solver_setup(solver, Amatrix);     // [AmgX] setup includes AMG hierarchy.
    AMGX_solver_solve(solver, rhs, sol);    // [AmgX] first solve with setup.
    // AMGX_vector_download(sol, d_vec);

    AMGX_vector_destroy(sol);       
    AMGX_vector_destroy(rhs);       


    //::: solver 2:::::::::::
    AMGX_vector_create(&rhs, rsrc, AMGX_mode_dDDI);
    AMGX_vector_create(&sol, rsrc, AMGX_mode_dDDI);

    const double *d_val_new = d_val;
    AMGX_matrix_replace_coefficients(Amatrix, n, nnz, d_val_new, NULL); // [AmgX] coefficient replacement.
    AMGX_vector_upload(rhs, n, 1, d_vec);
    AMGX_vector_set_zero(sol, n, 1);

    AMGX_solver_setup(solver, Amatrix);     // [AmgX] setup after coefficient replacement.
    AMGX_solver_solve(solver, rhs, sol);    // [AmgX] solve after coefficient replacement.
    // AMGX_vector_download(sol, d_vec);

    AMGX_vector_destroy(sol);
    AMGX_vector_destroy(rhs);


    //::: solver 3:::::::::::
    AMGX_vector_create(&rhs, rsrc, AMGX_mode_dDDI);
    AMGX_vector_create(&sol, rsrc, AMGX_mode_dDDI);

    AMGX_vector_upload(rhs, n, 1, d_vec);
    AMGX_vector_set_zero(sol, n, 1);

    AMGX_solver_solve(solver, rhs, sol);    // [AmgX] solve with existing solver object.
    AMGX_vector_download(sol, d_vec);       // [AmgX] write solution back to d_vec.
    

    // 정리
    AMGX_solver_destroy(solver);    //<<***!!!
    AMGX_matrix_destroy(Amatrix);   //<<***!!!
    AMGX_resources_destroy(rsrc);   //<<***!!!
    AMGX_config_destroy(cfg);       //<<***!!!

    AMGX_finalize();
}
