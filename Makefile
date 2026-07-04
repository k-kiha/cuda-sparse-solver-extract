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

CORE_SRC := src
FORTRAN_COMMON := examples/_common/fortran
OBJ_DIR := $(BUILD_DIR)/obj
LIB_DIR := $(BUILD_DIR)/lib
BIN_DIR := $(BUILD_DIR)/bin
RUN_DIR := $(BUILD_DIR)/run

CUDA_CXXFLAGS ?= -fPIC -cuda -O3 -I$(CORE_SRC) -I$(CUDA_INC_PATH)
FORTRAN_FLAGS ?= -cuda -O2
C_FLAGS ?= -O3 -std=gnu11 -Iinclude -I$(CUDA_INC_PATH)
RPATH_FLAGS := -Wl,-rpath,$(abspath $(LIB_DIR)) -Wl,-rpath,$(CUDA_LIB_PATH)
AMGX_RPATH_FLAGS := -Wl,-rpath,$(abspath $(AMGX_DIR)/lib)
NVTX_LIBS ?=
CUDA_LIBS := -L$(CUDA_LIB_PATH) -lcusparse -lcudart -lcublas $(NVTX_LIBS)

.PHONY: all env-check core core-amgx \
	lib-diag lib-ilu lib-amgx solver ilu amgx \
	examples examples-no-amgx examples-amgx \
	example-diag-c example-diag-fortran \
	example-ilu-c example-ilu-fortran \
	example-amgx-c example-amgx-fortran \
	example-c example-fortran \
	test test-no-amgx test-all \
	test-diag-c test-diag-fortran \
	test-ilu-c test-ilu-fortran \
	test-amgx-c test-amgx-fortran \
	amgx-fetch amgx-build amgx-install cupid-bridge \
	prepare-run-data prepare-run-data-amgx clean

all: core examples
core: lib-diag lib-ilu
core-amgx: lib-amgx
examples: examples-no-amgx
examples-no-amgx: example-diag-c example-diag-fortran example-ilu-c example-ilu-fortran
examples-amgx: example-amgx-c example-amgx-fortran

env-check:
	@command -v $(NVCXX) >/dev/null || { echo "missing NVCXX=$(NVCXX)"; exit 1; }
	@command -v $(NVFORTRAN) >/dev/null || { echo "missing NVFORTRAN=$(NVFORTRAN)"; exit 1; }
	@command -v $(NVC) >/dev/null || { echo "missing NVC=$(NVC)"; exit 1; }
	@test -n "$(CUDA_HOME)" || { echo "Set CUDA_HOME in config.mk."; exit 1; }
	@test -d "$(CUDA_INC_PATH)" || { echo "missing CUDA_INC_PATH=$(CUDA_INC_PATH)"; exit 1; }
	@test -d "$(CUDA_LIB_PATH)" || { echo "missing CUDA_LIB_PATH=$(CUDA_LIB_PATH)"; exit 1; }
	@echo "CUDA sparse solver core environment looks usable."

$(OBJ_DIR) $(LIB_DIR) $(BIN_DIR):
	mkdir -p $@

$(OBJ_DIR)/kkh_cudatools.o: $(CORE_SRC)/kkh_cudatools/kkh_cudatools.cu | $(OBJ_DIR)
	$(NVCXX) $(CUDA_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/kkh_iLU_cpu.o: $(CORE_SRC)/kkh_cudatools/kkh_iLU_cpu.cu | $(OBJ_DIR)
	$(NVCXX) $(CUDA_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/kkh_cudiagbicg.o: $(CORE_SRC)/solver3_diagbicg/kkh_cudiagbicg.cu | $(OBJ_DIR)
	$(NVCXX) $(CUDA_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/kkh_cuiLUbicg.o: $(CORE_SRC)/solver7_iLU/kkh_cuiLUbicg.cu | $(OBJ_DIR)
	$(NVCXX) $(CUDA_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/kkh_cuAmgX_recycle.o: $(CORE_SRC)/solver6_AmgX_recycle/kkh_cuAmgX.cu | $(OBJ_DIR)
	@test -d "$(AMGX_DIR)/include" || { echo "AmgX core path requires AMGX_DIR=$(AMGX_DIR). Run 'make amgx-install' or set AMGX_DIR."; exit 1; }
	$(NVCXX) $(CUDA_CXXFLAGS) -I$(AMGX_DIR)/include -c $< -o $@

$(OBJ_DIR)/kisti_solver_c_diag.o: $(CORE_SRC)/kisti_solver_c.cu | $(OBJ_DIR)
	$(NVCXX) $(CUDA_CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/kisti_solver_c_ilu.o: $(CORE_SRC)/kisti_solver_c.cu | $(OBJ_DIR)
	$(NVCXX) $(CUDA_CXXFLAGS) -DKISTI_SOLVER_ILU -c $< -o $@

$(OBJ_DIR)/kisti_solver_c_amgx.o: $(CORE_SRC)/kisti_solver_c.cu | $(OBJ_DIR)
	@test -d "$(AMGX_DIR)/include" || { echo "AmgX core path requires AMGX_DIR=$(AMGX_DIR). Run 'make amgx-install' or set AMGX_DIR."; exit 1; }
	$(NVCXX) $(CUDA_CXXFLAGS) -DKISTI_SOLVER_AMGX -I$(AMGX_DIR)/include -c $< -o $@

$(LIB_DIR)/libkisti_solver_c.so: $(OBJ_DIR)/kkh_cudatools.o $(OBJ_DIR)/kkh_cudiagbicg.o $(OBJ_DIR)/kisti_solver_c_diag.o | $(LIB_DIR)
	$(NVCXX) -fPIC -cuda -shared $^ $(CUDA_LIBS) -o $@

$(LIB_DIR)/libkisti_solver_c_ilu.so: $(OBJ_DIR)/kkh_cudatools.o $(OBJ_DIR)/kkh_iLU_cpu.o $(OBJ_DIR)/kkh_cuiLUbicg.o $(OBJ_DIR)/kisti_solver_c_ilu.o | $(LIB_DIR)
	$(NVCXX) -fPIC -cuda -shared $^ $(CUDA_LIBS) -o $@

$(LIB_DIR)/libkisti_solver_c_amgx.so: $(OBJ_DIR)/kkh_cudatools.o $(OBJ_DIR)/kkh_cuAmgX_recycle.o $(OBJ_DIR)/kisti_solver_c_amgx.o | $(LIB_DIR)
	@test -f "$(AMGX_DIR)/lib/libamgxsh.so" || { echo "AmgX core path requires $(AMGX_DIR)/lib/libamgxsh.so. Run 'make amgx-install' or set AMGX_DIR."; exit 1; }
	$(NVCXX) -fPIC -cuda -shared $^ -L$(AMGX_DIR)/lib -lamgxsh $(CUDA_LIBS) $(AMGX_RPATH_FLAGS) -o $@

lib-diag: $(LIB_DIR)/libkisti_solver_c.so
lib-ilu: $(LIB_DIR)/libkisti_solver_c_ilu.so
lib-amgx: $(LIB_DIR)/libkisti_solver_c_amgx.so

solver: lib-diag
ilu: lib-ilu
amgx: lib-amgx

$(OBJ_DIR)/mod_kisti.o: $(FORTRAN_COMMON)/mod_kisti.f90 | $(OBJ_DIR)
	$(NVFORTRAN) $(FORTRAN_FLAGS) -module $(OBJ_DIR) -c $< -o $@

$(OBJ_DIR)/main_diag_fortran.o: examples/diag_fortran/main.f90 $(OBJ_DIR)/mod_kisti.o | $(OBJ_DIR)
	$(NVFORTRAN) -I$(OBJ_DIR) -c $< -o $@

$(OBJ_DIR)/main_ilu_fortran.o: examples/ilu_fortran/main.f90 $(OBJ_DIR)/mod_kisti.o | $(OBJ_DIR)
	$(NVFORTRAN) -I$(OBJ_DIR) -c $< -o $@

$(OBJ_DIR)/main_amgx_fortran.o: examples/amgx_fortran/main.f90 $(OBJ_DIR)/mod_kisti.o | $(OBJ_DIR)
	$(NVFORTRAN) -I$(OBJ_DIR) -c $< -o $@

$(BIN_DIR)/diag_fortran.exe: $(OBJ_DIR)/main_diag_fortran.o $(OBJ_DIR)/mod_kisti.o $(LIB_DIR)/libkisti_solver_c.so | $(BIN_DIR)
	$(NVFORTRAN) $(FORTRAN_FLAGS) $(OBJ_DIR)/main_diag_fortran.o $(OBJ_DIR)/mod_kisti.o \
		-L$(LIB_DIR) -lkisti_solver_c $(RPATH_FLAGS) -L$(CUDA_LIB_PATH) -lcudart -o $@

$(BIN_DIR)/ilu_fortran.exe: $(OBJ_DIR)/main_ilu_fortran.o $(OBJ_DIR)/mod_kisti.o $(LIB_DIR)/libkisti_solver_c_ilu.so | $(BIN_DIR)
	$(NVFORTRAN) $(FORTRAN_FLAGS) $(OBJ_DIR)/main_ilu_fortran.o $(OBJ_DIR)/mod_kisti.o \
		-L$(LIB_DIR) -lkisti_solver_c_ilu $(RPATH_FLAGS) -L$(CUDA_LIB_PATH) -lcudart -o $@

$(BIN_DIR)/amgx_fortran.exe: $(OBJ_DIR)/main_amgx_fortran.o $(OBJ_DIR)/mod_kisti.o $(LIB_DIR)/libkisti_solver_c_amgx.so | $(BIN_DIR)
	$(NVFORTRAN) $(FORTRAN_FLAGS) $(OBJ_DIR)/main_amgx_fortran.o $(OBJ_DIR)/mod_kisti.o \
		-L$(LIB_DIR) -lkisti_solver_c_amgx $(RPATH_FLAGS) $(AMGX_RPATH_FLAGS) -L$(CUDA_LIB_PATH) -lcudart -o $@

example-diag-fortran: $(BIN_DIR)/diag_fortran.exe
example-ilu-fortran: $(BIN_DIR)/ilu_fortran.exe
example-amgx-fortran: $(BIN_DIR)/amgx_fortran.exe

$(OBJ_DIR)/main_diag_c.o: examples/diag_c/main.c | $(OBJ_DIR)
	$(NVC) $(C_FLAGS) -c $< -o $@

$(OBJ_DIR)/main_ilu_c.o: examples/ilu_c/main.c | $(OBJ_DIR)
	$(NVC) $(C_FLAGS) -c $< -o $@

$(OBJ_DIR)/main_amgx_c.o: examples/amgx_c/main.c | $(OBJ_DIR)
	$(NVC) $(C_FLAGS) -c $< -o $@

$(BIN_DIR)/diag_c.exe: $(OBJ_DIR)/main_diag_c.o $(LIB_DIR)/libkisti_solver_c.so | $(BIN_DIR)
	$(NVCXX) $(OBJ_DIR)/main_diag_c.o -L$(LIB_DIR) -lkisti_solver_c $(RPATH_FLAGS) -L$(CUDA_LIB_PATH) -lcudart -o $@

$(BIN_DIR)/ilu_c.exe: $(OBJ_DIR)/main_ilu_c.o $(LIB_DIR)/libkisti_solver_c_ilu.so | $(BIN_DIR)
	$(NVCXX) $(OBJ_DIR)/main_ilu_c.o -L$(LIB_DIR) -lkisti_solver_c_ilu $(RPATH_FLAGS) -L$(CUDA_LIB_PATH) -lcudart -o $@

$(BIN_DIR)/amgx_c.exe: $(OBJ_DIR)/main_amgx_c.o $(LIB_DIR)/libkisti_solver_c_amgx.so | $(BIN_DIR)
	$(NVCXX) $(OBJ_DIR)/main_amgx_c.o -L$(LIB_DIR) -lkisti_solver_c_amgx $(RPATH_FLAGS) $(AMGX_RPATH_FLAGS) -L$(CUDA_LIB_PATH) -lcudart -o $@

example-diag-c: $(BIN_DIR)/diag_c.exe
example-ilu-c: $(BIN_DIR)/ilu_c.exe
example-amgx-c: $(BIN_DIR)/amgx_c.exe

example-c: example-diag-c
example-fortran: example-diag-fortran

prepare-run-data:
	mkdir -p $(RUN_DIR)/diag_c/Mtest $(RUN_DIR)/diag_fortran/Mtest
	mkdir -p $(RUN_DIR)/ilu_c/Mtest $(RUN_DIR)/ilu_fortran/Mtest
	cp data/small_csr/*.txt $(RUN_DIR)/diag_c/Mtest/
	cp data/small_csr/*.txt $(RUN_DIR)/diag_fortran/Mtest/
	cp data/small_csr/*.txt $(RUN_DIR)/ilu_c/Mtest/
	cp data/small_csr/*.txt $(RUN_DIR)/ilu_fortran/Mtest/

prepare-run-data-amgx: prepare-run-data
	mkdir -p $(RUN_DIR)/amgx_c/Mtest $(RUN_DIR)/amgx_fortran/Mtest
	cp data/small_csr/*.txt $(RUN_DIR)/amgx_c/Mtest/
	cp data/small_csr/*.txt $(RUN_DIR)/amgx_fortran/Mtest/
	cp examples/amgx_config/amgx_config.json $(RUN_DIR)/amgx_c/amgx_config.json
	cp examples/amgx_config/amgx_config.json $(RUN_DIR)/amgx_fortran/amgx_config.json

test-diag-c: example-diag-c prepare-run-data
	cd $(RUN_DIR)/diag_c && $(abspath $(BIN_DIR)/diag_c.exe) && test -s result_c.txt

test-diag-fortran: example-diag-fortran prepare-run-data
	cd $(RUN_DIR)/diag_fortran && $(abspath $(BIN_DIR)/diag_fortran.exe) && test -s result.txt

test-ilu-c: example-ilu-c prepare-run-data
	cd $(RUN_DIR)/ilu_c && $(abspath $(BIN_DIR)/ilu_c.exe) && test -s result_c.txt

test-ilu-fortran: example-ilu-fortran prepare-run-data
	cd $(RUN_DIR)/ilu_fortran && $(abspath $(BIN_DIR)/ilu_fortran.exe) && test -s result.txt

test-amgx-c: example-amgx-c prepare-run-data-amgx
	cd $(RUN_DIR)/amgx_c && $(abspath $(BIN_DIR)/amgx_c.exe) && test -s result_c.txt

test-amgx-fortran: example-amgx-fortran prepare-run-data-amgx
	cd $(RUN_DIR)/amgx_fortran && $(abspath $(BIN_DIR)/amgx_fortran.exe) && test -s result.txt

test-no-amgx: test-diag-c test-diag-fortran test-ilu-c test-ilu-fortran
test-all: test-no-amgx test-amgx-c test-amgx-fortran
test: test-no-amgx

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
	@echo "Run 'make lib-amgx' or 'make test-amgx-c' to validate the AmgX core path."

cupid-bridge:
	@echo "CUPID/gfortran bridge sources are staged in integration/cupid_gfortran_bridge."
	@echo "Use this path as the integration evidence layer after the three core solver paths are validated."

clean:
	rm -rf $(BUILD_DIR)
