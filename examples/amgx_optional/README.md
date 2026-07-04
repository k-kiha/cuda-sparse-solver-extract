# Optional AmgX Path

This optional path demonstrates NVIDIA AmgX integration.

Core files:

- `src/cuda/solver5_AmgX/kkh_cuAmgX.cu`
- `src/cuda/solver6_AmgX_recycle/kkh_cuAmgX.cu`
- `examples/amgx_optional/amgx_config.json`

Evidence value:

- AmgX initialization and JSON configuration
- CSR matrix upload into AmgX
- AMG/Krylov solver setup and solve
- coefficient replacement/reuse path for repeated solves

Build:

```bash
make amgx-install
make amgx
```

This is optional evidence and is not required for default `make` or `make test`.
The default repo-local AmgX prefix is `.local/amgx`, and the helper scripts are
kept under `tools/amgx/`.

Use this path to discuss setup cost versus per-solve reuse.
