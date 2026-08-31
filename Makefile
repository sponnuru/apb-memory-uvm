VERILATOR ?= verilator
UVM_HOME ?= $(CURDIR)/third_party/uvm
JOBS ?= 4
SEED ?= 1
SOURCES = rtl/apb_memory.sv tb/apb_if.sv tb/apb_pkg.sv tb/tb_top.sv
.PHONY: all build run test clean
all: test
build: build/obj/Vtb_top
build/obj/Vtb_top: $(SOURCES) tb/trace.vlt tb/sim_main.cpp Makefile $(UVM_HOME)/src/uvm_pkg.sv
	mkdir -p build
	$(VERILATOR) --cc --exe --build --timing --assert --trace -j $(JOBS) --top-module tb_top \
	  --Mdir build/obj -Wno-fatal +define+UVM_NO_DPI +incdir+$(UVM_HOME)/src \
	  tb/trace.vlt $(UVM_HOME)/src/uvm_pkg.sv $(SOURCES) $(CURDIR)/tb/sim_main.cpp > build/compile.log 2>&1 || \
	  { tail -100 build/compile.log; exit 1; }
run: build
	python3 scripts/run_test.py --seed $(SEED)
test: build
	python3 scripts/run_test.py --seed 1 --seed 42 --seed 2026
clean:
	rm -rf build
