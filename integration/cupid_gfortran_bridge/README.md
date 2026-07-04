# CUPID/gfortran Bridge Evidence

This directory keeps the compact integration evidence for a CUPID-like
application built with `gfortran` while the CUDA layer is built with NVHPC.

Files:

- `main.f90`: simple application-side driver
- `kistimod_kkh_profile.f90`: gfortran-side C binding wrapper
- `kisti_api.f90`: NVFORTRAN-side API bridge
- `mod_kisti_bridge.f90`: NVFORTRAN CUDA device-array layer
- `env.example.sh`: target-system module-loading template

This path is staged as integration evidence and is not part of default `make`,
`make examples`, or `make test`. Validate the core CUDA solver first, then
adapt this bridge to the target CUPID build system.
