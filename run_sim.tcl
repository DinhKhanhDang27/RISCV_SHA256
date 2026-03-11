# ============================================================================
# ModelSim TCL Script - Run with: do run_sim.tcl
# ============================================================================

# Create work library
vlib work

# Compile all source files
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
vlog riscv_top.v
vlog riscv_tb.v

# Load simulation
vsim work.riscv_tb

# Add waves
add wave -divider "Clock & Reset"
add wave sim:/riscv_tb/clk
add wave sim:/riscv_tb/rst

add wave -divider "Program Counter"
add wave -radix hexadecimal sim:/riscv_tb/dut/pc_current
add wave -radix hexadecimal sim:/riscv_tb/dut/pc_plus4
add wave -radix hexadecimal sim:/riscv_tb/dut/pc_next

add wave -divider "Instruction"
add wave -radix hexadecimal sim:/riscv_tb/dut/instruction
add wave -radix binary sim:/riscv_tb/dut/opcode
add wave -radix unsigned sim:/riscv_tb/dut/rd
add wave -radix unsigned sim:/riscv_tb/dut/rs1
add wave -radix unsigned sim:/riscv_tb/dut/rs2
add wave -radix binary sim:/riscv_tb/dut/funct3
add wave -radix binary sim:/riscv_tb/dut/funct7

add wave -divider "Control Signals"
add wave sim:/riscv_tb/dut/ctrl_branch
add wave sim:/riscv_tb/dut/ctrl_mem_read
add wave sim:/riscv_tb/dut/ctrl_mem_to_reg
add wave -radix binary sim:/riscv_tb/dut/ctrl_alu_op
add wave sim:/riscv_tb/dut/ctrl_mem_write
add wave sim:/riscv_tb/dut/ctrl_alu_src
add wave sim:/riscv_tb/dut/ctrl_reg_write
add wave sim:/riscv_tb/dut/ctrl_jump
add wave sim:/riscv_tb/dut/ctrl_jalr

add wave -divider "ALU"
add wave -radix hexadecimal sim:/riscv_tb/dut/alu_input_a
add wave -radix hexadecimal sim:/riscv_tb/dut/alu_input_b
add wave -radix binary sim:/riscv_tb/dut/alu_ctrl
add wave -radix hexadecimal sim:/riscv_tb/dut/alu_result
add wave sim:/riscv_tb/dut/alu_zero

add wave -divider "Immediate"
add wave -radix decimal sim:/riscv_tb/dut/imm

add wave -divider "Branch"
add wave sim:/riscv_tb/dut/branch_taken

add wave -divider "Register File"
add wave -radix decimal sim:/riscv_tb/dut/reg_read_data1
add wave -radix decimal sim:/riscv_tb/dut/reg_read_data2
add wave -radix decimal sim:/riscv_tb/dut/reg_write_data

add wave -divider "Key Registers"
add wave -radix decimal sim:/riscv_tb/dut/u_regfile/registers(1)
add wave -radix decimal sim:/riscv_tb/dut/u_regfile/registers(2)
add wave -radix decimal sim:/riscv_tb/dut/u_regfile/registers(3)
add wave -radix decimal sim:/riscv_tb/dut/u_regfile/registers(5)
add wave -radix decimal sim:/riscv_tb/dut/u_regfile/registers(10)

add wave -divider "Write-back"
add wave -radix binary sim:/riscv_tb/dut/wb_sel
add wave -radix decimal sim:/riscv_tb/dut/reg_write_data

# Run simulation
run -all

# Zoom to fit
wave zoom full
