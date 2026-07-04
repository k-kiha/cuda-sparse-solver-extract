# AmgX Runtime Configuration

`src/solver5_AmgX` and `src/solver6_AmgX_recycle` call:

```c
AMGX_config_create_from_file(&cfg, "amgx_config.json");
```

The Makefile copies this directory's `amgx_config.json` into each AmgX run
directory before `test-amgx-c` or `test-amgx-fortran` executes.
