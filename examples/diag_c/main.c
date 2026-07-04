// C caller for the CUDA sparse solver core.
// It allocates CUDA device memory directly and calls the same kisti_solver_c
// ABI used by the Fortran bind(C) path.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <cuda_runtime.h>
#include <time.h>

// ***************************************************
// kisti_solver 헤더
#include "kisti_solver_c.h" // << 핵심(1/2)!!
// ***************************************************

// --------- 유틸: 텍스트 파일에서 배열 읽기 ----------
static void read_int_array(const char *path, int len, int *out);
static void read_double_array(const char *path, int len, double *out);
static void read_nm(const char *path, int *N, int *M);
static inline double wall_time_s(void) ;

int main(void) {
    // 0) N, M 읽기
    int N = 0, M = 0;
    read_nm("./Mtest/spmv_nm.txt", &N, &M);
    printf("KISTI Ax=b (C main) — N=%d, M=%d\n", N, M);


    // 1) 호스트 메모리 할당 & 로드
    int    *h_rowPtr = (int*)    malloc((size_t)(N+1) * sizeof(int));
    int    *h_colInd = (int*)    malloc((size_t) M    * sizeof(int));
    double *h_val    = (double*) malloc((size_t) M    * sizeof(double));
    double *h_b      = (double*) malloc((size_t) N    * sizeof(double));
    double *h_x      = (double*) malloc((size_t) N    * sizeof(double));


    read_int_array   ("./Mtest/spmv_Arowp.txt", N+1, h_rowPtr);
    read_int_array   ("./Mtest/spmv_Acoli.txt", M  , h_colInd);
    read_double_array("./Mtest/spmv_Aval.txt" , M  , h_val);
    read_double_array("./Mtest/spmv_b.txt"    , N  , h_b);
    read_double_array("./Mtest/spmv_x.txt"    , N  , h_x);


    // [CUDA Runtime] 디바이스 CSR/vector 메모리 할당
    int    *d_rowPtr = NULL;
    int    *d_colInd = NULL;
    double *d_val    = NULL;
    double *d_bx     = NULL; // 입력 b, 출력 x (in-place)

    cudaMalloc((void**)&d_rowPtr, (size_t)(N+1) * sizeof(int));
    cudaMalloc((void**)&d_colInd, (size_t) M    * sizeof(int));
    cudaMalloc((void**)&d_val   , (size_t) M    * sizeof(double));
    cudaMalloc((void**)&d_bx    , (size_t) N    * sizeof(double));
    
    double t0_a,t1_a,t2_a;
    double t0_b,t1_b,t2_b;

    // [CUDA Runtime] H2D 복사 

    t0_a = wall_time_s();
    cudaMemcpy(d_rowPtr, h_rowPtr, (size_t)(N+1)*sizeof(int),    cudaMemcpyHostToDevice);
    cudaMemcpy(d_colInd, h_colInd, (size_t) M   *sizeof(int),    cudaMemcpyHostToDevice);
    cudaMemcpy(d_val   , h_val   , (size_t) M   *sizeof(double), cudaMemcpyHostToDevice);
    cudaMemcpy(d_bx    , h_b     , (size_t) N   *sizeof(double), cudaMemcpyHostToDevice);
    t0_b = wall_time_s();

    // ***************************************************
    // [C-CUDA ABI] Fortran path와 동일한 public ABI 호출
    t1_a = wall_time_s();
    kisti_solver_c(N, M, d_rowPtr, d_colInd, d_val, d_bx); // << 핵심(2/2)!!
    t1_b = wall_time_s();
    // ***************************************************

    // 5) 결과 D2H 복사
    t2_a = wall_time_s();
    cudaMemcpy(h_b, d_bx, (size_t) N * sizeof(double), cudaMemcpyDeviceToHost);
    t2_b = wall_time_s();


    printf("H2D  :%30.15E\n",t0_b-t0_a);
    printf("Compu:%30.15E\n",t1_b-t1_a);
    printf("D2H  :%30.15E\n",t2_b-t2_a);
    printf("-------------------------------------\n");
    printf("Wtime(sec)           ::%30.15E\n", t2_b-t0_a);
    printf("-------------------------------------\n");

    // 결과 파일 저장 (xref=b, x, diff)
    {
        FILE *fo = fopen("./result_c.txt", "w");
        if (fo) {
            fprintf(fo, "%-8s%20s%20s%20s\n", "index", "xref", "x", "diff");
            fprintf(fo, "%-8s%20s%20s%20s\n", "------", "------", "------", "------");
            for (int i = 0; i < N; ++i) {
                fprintf(fo, "%8d%20.12e%20.12e%20.12e\n", i+1, h_x[i], h_b[i], h_x[i]-h_b[i]);
            }
            fclose(fo);
        } else {
            perror("result_c.txt");
        }
    }
    

    // 7) 정리
    cudaFree(d_rowPtr);
    cudaFree(d_colInd);
    cudaFree(d_val);
    cudaFree(d_bx);

    free(h_rowPtr);
    free(h_colInd);
    free(h_val);
    free(h_b);
    free(h_x);

    return 0;
}



// --------- 유틸: 텍스트 파일에서 배열 읽기 ----------
static void read_int_array(const char *path, int len, int *out) {
    FILE *fp = fopen(path, "r");
    if (!fp) { perror(path); exit(EXIT_FAILURE); }
    for (int i = 0; i < len; ++i) {
        if (fscanf(fp, "%d", &out[i]) != 1) {
            fprintf(stderr, "Failed to read int at %s[%lld]\n", path, (long long)i);
            fclose(fp);
            exit(EXIT_FAILURE);
        }
    }
    fclose(fp);
}

static void read_double_array(const char *path, int len, double *out) {
    FILE *fp = fopen(path, "r");
    if (!fp) { perror(path); exit(EXIT_FAILURE); }
    for (int i = 0; i < len; ++i) {
        if (fscanf(fp, "%lf", &out[i]) != 1) {
            fprintf(stderr, "Failed to read double at %s[%lld]\n", path, (long long)i);
            fclose(fp);
            exit(EXIT_FAILURE);
        }
    }
    fclose(fp);
}

static void read_nm(const char *path, int *N, int *M) {
    FILE *fp = fopen(path, "r");
    if (!fp) { perror(path); exit(EXIT_FAILURE); }
    if (fscanf(fp, "%d", N) != 1) { fprintf(stderr, "read N failed\n"); exit(EXIT_FAILURE); }
    if (fscanf(fp, "%d", M) != 1) { fprintf(stderr, "read M failed\n"); exit(EXIT_FAILURE); }
    fclose(fp);
}

// 간단한 wall-clock 타이머 (초 단위)
static inline double wall_time_s(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + 1e-9 * (double)ts.tv_nsec;
}
