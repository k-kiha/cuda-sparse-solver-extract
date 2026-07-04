# Optional iLU + cuSPARSE SpSV Path

This optional path demonstrates an iLU(0)-preconditioned BiCGStab experiment.

Core files:

- `src/cuda/solver7_iLU/kkh_cuiLUbicg.cu`
- `src/cuda/kkh_cudatools/kkh_iLU_cpu.cu`
- `src/cuda/kkh_cudatools/kkh_cudatools.cu`

Evidence value:

- CPU-side iLU(0) factorization
- L/U CSR transfer back to the GPU
- cuSPARSE SpSV lower/upper triangular solves
- cuBLAS dot products in the Krylov loop

Build:

```bash
make ilu
```

This is optional evidence, not the main headline path. It does not run during
default `make` or `make test`. It is useful because it explains why GPU ILU can
be limited by sparse triangular solves.
