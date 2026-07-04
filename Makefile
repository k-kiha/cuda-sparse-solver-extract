-include config.mk

NVFORTRAN ?= nvfortran
NVC ?= nvc
NVCXX ?= nvc++
CUDA_HOME ?=
CUDA_INC_PATH ?= $(if $(CUDA_HOME),$(CUDA_HOME)/include,)
CUDA_LIB_PATH ?= $(if $(CUDA_HOME),$(CUDA_HOME)/lib64,)
AMGX_DIR ?= $(CURDIR)/.local/amgx
AMGX_SRC_DIR ?= $(CURDIR)/external/AMGX
AMGX_BUILD_DIR ?= $(AMGX_SRC_DIR)/build
AMGX_CUDA_ARCH ?= 80
BUILD_DIR ?= build

CUDA_SRC := src/cuda
FORTRAN_SRC := src/fortran
OBJ_DIR := $(BUILD_DIR)/obj
LIB_DIR := $(BUILD_DIR)/lib
BIN_DIR := $(BUILD_DIR)/bin
RUN_DIR := $(BUILD_DIR)/run

CUDA_CXXFLAGS ?= -fPIC -cuda -O3 -I$(CUDA_SRC) -I$(CUDA_INC_PATH)
FORTRAN_FLAGS ?= -cuda -O2
C_FLAGS ?= -O3 -std=gnu11 -Iinclude -I$(CUDA_INC_PATH)
RPATH_FLAGS := -Wl,-rpath,$(abspath $(LIB_DIR)) -Wl,-rpath,$(CUDA_LIB_PATH)
CUDA_LIBS := -L$(CUDA_LIB_PATH) -lcusparse -lcudart -lcublas -lnvToolsExt

.PHONY: all env-check solver example-fortran example-c test ilu amgx amgx-fetch amgx-build amgx-install cupid-bridge clean prepare-run-data

all: solver example-fortran example-c

env-check:
	@command -v $(NVCXX) >/dev/null || { echo "missing NVCXX=$(NVCXX)"; exit 1; }
	@command -v $(NVFORTRAN) >/dev/null || { echo "missing NVFORTRAN=$(NVFORTRAN)"; exit 1; }
	@command -v $(NVC) >/dev/null || { echo "missing NVC=$(NVC)"; exit 1; }
	@test -n "$(CUDA_HOME)" || { echo "Set CUDA_HOME in config.mk."; exit 1; }
	@test -d "$(CUDA_INC_PATH)" || { echo "missing CUDA_INC_PATH=$(CUDA_INC_PATH)"; exit 1; }
	@test -d "$(CUDA_LIB_PATH)" || { echo "missing CUDA_LIB_PATH=$(CUDA_LIB_PATH)"; exit 1; }
	@echo "CUDA showcase environment looks usable."

$(OBJ_DIR) $(LIB_DIR) $(BIN_DIR):
	mkdir -p $@

$(OBJ_DIR)/kkh_cudatools.o: $(CUDA_SRC)/kkh_cudatools/kkh_cudatools.cu | $(OBJ_DIR)
	$(NVCXX) $(CUDA_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/kkh_iLU_cpu.o: $(CUDA_SRC)/kkh_cudatools/kkh_iLU_cpu.cu | $(OBJ_DIR)
	$(NVCXX) $(CUDA_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/kkh_cudiagbicg.o: $(CUDA_SRC)/solver3_diagbicg/kkh_cudiagbicg.cu | $(OBJ_DIR)
	$(NVCXX) $(CUDA_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/kkh_cuiLUbicg.o: $(CUDA_SRC)/solver7_iLU/kkh_cuiLUbicg.cu | $(OBJ_DIR)
	$(NVCXX) $(CUDA_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/kkh_cuAmgX_recycle.o: $(CUDA_SRC)/solver6_AmgX_recycle/kkh_cuAmgX.cu | $(OBJ_DIR)
	@test -d "$(AMGX_DIR)/include" || { echo "Missing AmgX include dir: $(AMGX_DIR)/include. Run 'make amgx-install' or set AMGX_DIR."; exit 1; }
	$(NVCXX) $(CUDA_CXXFLAGS) -I$(AMGX_DIR)/include -c $< -o $@

$(OBJ_DIR)/kisti_solver_c_diag.o: $(CUDA_SRC)/kisti_solver_c.cu | $(OBJ_DIR)
	$(NVCXX) $(CUDA_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/kisti_solver_c_ilu.o: $(CUDA_SRC)/kisti_solver_c.cu | $(OBJ_DIR)
	$(NVCXX) $(CUDA_CXXFLAGS) -DKISTI_SOLVER_ILU -c $< -o $@

$(OBJ_DIR)/kisti_solver_c_amgx.o: $(CUDA_SRC)/kisti_solver_c.cu | $(OBJ_DIR)
	@test -d "$(AMGX_DIR)/include" || { echo "Missing AmgX include dir: $(AMGX_DIR)/include. Run 'make amgx-install' or set AMGX_DIR."; exit 1; }
	$(NVCXX) $(CUDA_CXXFLAGS) -DKISTI_SOLVER_AMGX -I$(AMGX_DIR)/include -c $< -o $@

$(LIB_DIR)/libkisti_solver_c.so: $(OBJ_DIR)/kkh_cudatools.o $(OBJ_DIR)/kkh_cudiagbicg.o $(OBJ_DIR)/kisti_solver_c_diag.o | $(LIB_DIR)
	$(NVCXX) -fPIC -cuda -shared $^ $(CUDA_LIBS) -o $@

$(LIB_DIR)/libkisti_solver_c_ilu.so: $(OBJ_DIR)/kkh_cudatools.o $(OBJ_DIR)/kkh_iLU_cpu.o $(OBJ_DIR)/kkh_cuiLUbicg.o $(OBJ_DIR)/kisti_solver_c_ilu.o | $(LIB_DIR)
	$(NVCXX) -fPIC -cuda -shared $^ $(CUDA_LIBS) -o $@

$(LIB_DIR)/libkisti_solver_c_amgx.so: $(OBJ_DIR)/kkh_cudatools.o $(OBJ_DIR)/kkh_cuAmgX_recycle.o $(OBJ_DIR)/kisti_solver_c_amgx.o | $(LIB_DIR)
	@test -f "$(AMGX_DIR)/lib/libamgxsh.so" || { echo "Missing AmgX shared library: $(AMGX_DIR)/lib/libamgxsh.so. Run 'make amgx-install' or set AMGX_DIR."; exit 1; }
	$(NVCXX) -fPIC -cuda -shared $^ -L$(AMGX_DIR)/lib -lamgxsh $(CUDA_LIBS) -Wl,-rpath,$(AMGX_DIR)/lib -o $@

solver: $(LIB_DIR)/libkisti_solver_c.so

ilu: $(LIB_DIR)/libkisti_solver_c_ilu.so

amgx: $(LIB_DIR)/libkisti_solver_c_amgx.so

amgx-fetch:
	AMGX_SRC_DIR="$(abspath $(AMGX_SRC_DIR))" tools/amgx/fetch_amgx.sh

amgx-build:
	AMGX_SRC_DIR="$(abspath $(AMGX_SRC_DIR))" \
	AMGX_BUILD_DIR="$(abspath $(AMGX_BUILD_DIR))" \
	AMGX_INSTALL_DIR="$(abspath $(AMGX_DIR))" \
	AMGX_CUDA_ARCH="$(AMGX_CUDA_ARCH)" \
	tools/amgx/build_amgx.sh

amgx-install: amgx-fetch amgx-build
	@echo "AmgX installed under $(abspath $(AMGX_DIR))."
	@echo "Run 'make amgx' to build the optional AmgX solver path."

$(OBJ_DIR)/mod_kisti.o: $(FORTRAN_SRC)/mod_kisti.f90 | $(OBJ_DIR)
	$(NVFORTRAN) $(FORTRAN_FLAGS) -module $(OBJ_DIR) -c $< -o $@

$(OBJ_DIR)/main_fortran.o: examples/fortran_csr/main.f90 $(OBJ_DIR)/mod_kisti.o | $(OBJ_DIR)
	$(NVFORTRAN) -I$(OBJ_DIR) -c $< -o $@

$(BIN_DIR)/fortran_csr.exe: $(OBJ_DIR)/main_fortran.o $(OBJ_DIR)/mod_kisti.o $(LIB_DIR)/libkisti_solver_c.so | $(BIN_DIR)
	$(NVFORTRAN) $(FORTRAN_FLAGS) $(OBJ_DIR)/main_fortran.o $(OBJ_DIR)/mod_kisti.o \
		-L$(LIB_DIR) -lkisti_solver_c $(RPATH_FLAGS) -L$(CUDA_LIB_PATH) -lcudart -o $@

example-fortran: $(BIN_DIR)/fortran_csr.exe

$(OBJ_DIR)/main_c.o: examples/c_csr/main.c | $(OBJ_DIR)
	$(NVC) $(C_FLAGS) -c $< -o $@

$(BIN_DIR)/c_csr.exe: $(OBJ_DIR)/main_c.o $(LIB_DIR)/libkisti_solver_c.so | $(BIN_DIR)
	$(NVCXX) $(OBJ_DIR)/main_c.o -L$(LIB_DIR) -lkisti_solver_c $(RPATH_FLAGS) -L$(CUDA_LIB_PATH) -lcudart -o $@

example-c: $(BIN_DIR)/c_csr.exe

prepare-run-data:
	mkdir -p $(RUN_DIR)/fortran_csr/Mtest $(RUN_DIR)/c_csr/Mtest
	cp data/small_csr/*.txt $(RUN_DIR)/fortran_csr/Mtest/
	cp data/small_csr/*.txt $(RUN_DIR)/c_csr/Mtest/

test: example-fortran example-c prepare-run-data
	cd $(RUN_DIR)/fortran_csr && $(abspath $(BIN_DIR)/fortran_csr.exe) && test -s result.txt
	cd $(RUN_DIR)/c_csr && $(abspath $(BIN_DIR)/c_csr.exe) && test -s result_c.txt

cupid-bridge:
	@echo "CUPID/gfortran bridge sources are staged in examples/cupid_gfortran_bridge."
	@echo "Use this path as the integration evidence layer after the core solver is validated."

clean:
	rm -rf $(BUILD_DIR)
