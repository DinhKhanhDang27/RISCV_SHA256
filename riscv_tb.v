// ============================================================================
// RISC-V 64-bit Datapath Testbench
// For simulation in ModelSim
// ============================================================================
`timescale 1ns / 1ps

module riscv_tb;

    // ========================================================================
    // Signals
    // ========================================================================
    reg clk;
    reg rst;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    riscv_top dut (
        .clk (clk),
        .rst (rst)
    );

    // ========================================================================
    // Clock generation: 10ns period (100MHz)
    // ========================================================================
    initial clk = 0;
    always #5 clk = ~clk;

    // ========================================================================
    // Test sequence
    // ========================================================================
    integer i;
    
    initial begin
        // Reset
        rst = 1;
        #20;
        rst = 0;

        // Wait for program to execute
        // Part 1: sum of 1..10 loop (~26 instructions)
        // Part 2: SHA-256 hash computation (~120 clock cycles for SHA engine)
        // Total: ~200+ cycles, give plenty of time
        #3000;

        // Display register contents
        $display("============================================");
        $display("RISC-V 64-bit Datapath - Simulation Results");
        $display("============================================");
        $display("Time = %0t ns", $time);
        $display("");
        
        $display("--- Register File Contents ---");
        for (i = 0; i < 32; i = i + 1) begin
            $display("x%-2d = %0d (0x%016h)", i, 
                     dut.u_regfile.registers[i],
                     dut.u_regfile.registers[i]);
        end
        
        $display("");
        $display("=== Part 1: Sum of 1..10 ===");
        
        if (dut.u_regfile.registers[1] == 64'd55)
            $display("PASS: x1 = 55 (sum of 1..10)");
        else
            $display("FAIL: x1 = %0d, expected 55", dut.u_regfile.registers[1]);
            
        if (dut.u_regfile.registers[2] == 64'd11)
            $display("PASS: x2 = 11 (counter after loop)");
        else
            $display("FAIL: x2 = %0d, expected 11", dut.u_regfile.registers[2]);
            
        if (dut.u_regfile.registers[3] == 64'd10)
            $display("PASS: x3 = 10 (limit)");
        else
            $display("FAIL: x3 = %0d, expected 10", dut.u_regfile.registers[3]);

        if (dut.u_regfile.registers[5] == 64'd55)
            $display("PASS: x5 = 55 (loaded from memory)");
        else
            $display("FAIL: x5 = %0d, expected 55", dut.u_regfile.registers[5]);
            
        if (dut.u_regfile.registers[6] == 64'd55)
            $display("PASS: x6 = 55 (AND result)");
        else
            $display("FAIL: x6 = %0d, expected 55", dut.u_regfile.registers[6]);
            
        if (dut.u_regfile.registers[7] == 64'd55)
            $display("PASS: x7 = 55 (OR result)");
        else
            $display("FAIL: x7 = %0d, expected 55", dut.u_regfile.registers[7]);
            
        if (dut.u_regfile.registers[8] == 64'd0)
            $display("PASS: x8 = 0 (SUB result)");
        else
            $display("FAIL: x8 = %0d, expected 0", dut.u_regfile.registers[8]);

        $display("");
        $display("=== Part 2: SHA-256 Hash of \"abc\" ===");
        $display("Expected: ba7816bf 8f01cfea 414140de 5dae2223");
        $display("          b00361a3 96177a9c b410ff61 f20015ad");
        $display("");
        
        // SHA-256 status
        $display("SHA-256 Done = %b", dut.u_sha256.done);
        $display("");
        
        // Display hash in registers
        $display("Hash H0:H1 (x26) = 0x%016h", dut.u_regfile.registers[26]);
        $display("Hash H2:H3 (x27) = 0x%016h", dut.u_regfile.registers[27]);
        $display("Hash H4:H5 (x28) = 0x%016h", dut.u_regfile.registers[28]);
        $display("Hash H6:H7 (x29) = 0x%016h", dut.u_regfile.registers[29]);
        $display("");
        
        // Display individual hash words from SHA engine
        $display("SHA-256 Engine Output:");
        $display("  H0 = %08h  (expect ba7816bf)", dut.u_sha256.H0);
        $display("  H1 = %08h  (expect 8f01cfea)", dut.u_sha256.H1);
        $display("  H2 = %08h  (expect 414140de)", dut.u_sha256.H2);
        $display("  H3 = %08h  (expect 5dae2223)", dut.u_sha256.H3);
        $display("  H4 = %08h  (expect 510e527f -> b00361a3)", dut.u_sha256.H4);
        $display("  H5 = %08h  (expect 9b05688c -> 96177a9c)", dut.u_sha256.H5);
        $display("  H6 = %08h  (expect 1f83d9ab -> b410ff61)", dut.u_sha256.H6);
        $display("  H7 = %08h  (expect 5be0cd19 -> f20015ad)", dut.u_sha256.H7);
        $display("");
        
        // Verify SHA-256 hash
        if (dut.u_sha256.H0 == 32'hba7816bf &&
            dut.u_sha256.H1 == 32'h8f01cfea &&
            dut.u_sha256.H2 == 32'h414140de &&
            dut.u_sha256.H3 == 32'h5dae2223 &&
            dut.u_sha256.H4 == 32'hb00361a3 &&
            dut.u_sha256.H5 == 32'h96177a9c &&
            dut.u_sha256.H6 == 32'hb410ff61 &&
            dut.u_sha256.H7 == 32'hf20015ad)
            $display("SHA-256 PASS: Hash matches expected value!");
        else
            $display("SHA-256 FAIL: Hash does NOT match expected value.");
        
        $display("");
        $display("--- Data Memory[0] ---");
        $display("mem[0] = 0x%02h%02h%02h%02h%02h%02h%02h%02h",
            dut.u_dmem.mem[7], dut.u_dmem.mem[6],
            dut.u_dmem.mem[5], dut.u_dmem.mem[4],
            dut.u_dmem.mem[3], dut.u_dmem.mem[2],
            dut.u_dmem.mem[1], dut.u_dmem.mem[0]);
        
        $display("");
        $display("--- Final PC ---");
        $display("PC = 0x%016h", dut.pc_current);
        
        $display("============================================");
        $display("Simulation Complete");
        $display("============================================");
        
        $stop;
    end

    // ========================================================================
    // Waveform dump for ModelSim
    // ========================================================================
    initial begin
        $dumpfile("riscv_wave.vcd");
        $dumpvars(0, riscv_tb);
    end

    // ========================================================================
    // Monitor PC and instruction each cycle
    // ========================================================================
    always @(posedge clk) begin
        if (!rst) begin
            $display("[%0t] PC=0x%h  Instr=0x%08h  x1=%0d  x2=%0d", 
                     $time, dut.pc_current, dut.u_imem.instruction, 
                     dut.u_regfile.registers[1], dut.u_regfile.registers[2]);
        end
    end

endmodule
