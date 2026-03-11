@echo off
REM ============================================================================
REM ModelSim Simulation Script for RISC-V 64-bit Datapath
REM Run this batch file in the project directory
REM ============================================================================

echo ============================================
echo  RISC-V 64-bit Datapath - ModelSim Compile
echo ============================================

REM Create work library
vlib work

REM Compile all Verilog sources
vlog alu.v
vlog alu_control.v
vlog register_file.v
vlog instruction_memory.v
vlog data_memory.v
vlog pc_register.v
vlog adder.v
vlog imm_gen.v
vlog control_unit.v
vlog branch_control.v
vlog mux.v
vlog sha256.v
vlog riscv_top.v
vlog riscv_tb.v

REM Run simulation
vsim -c work.riscv_tb -do "run -all; quit"

echo ============================================
echo  Simulation Complete
echo ============================================
pause
