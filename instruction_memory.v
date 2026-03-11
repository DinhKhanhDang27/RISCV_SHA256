// ============================================================================
// RISC-V Instruction Memory (ROM)
// 256 words x 32-bit instructions
// Byte-addressable, word-aligned reads
// Pre-loaded with test program
// ============================================================================
module instruction_memory (
    input  [63:0] addr,
    output [31:0] instruction
);

    reg [31:0] mem [0:255];

    assign instruction = mem[addr[9:2]]; // Word-aligned access

    initial begin
        // ================================================================
        // Test program Part 1: compute sum of 1 to 10 (original test)
        // ================================================================
        // addi x1, x0, 0      ; x1 = 0 (sum)
        mem[0]  = 32'h00000093;
        // addi x2, x0, 1      ; x2 = 1 (counter)
        mem[1]  = 32'h00100113;
        // addi x3, x0, 10     ; x3 = 10 (limit)
        mem[2]  = 32'h00a00193;
        // addi x4, x0, 1      ; x4 = 1 (increment)
        mem[3]  = 32'h00100213;
        
        // LOOP (addr 16 = 0x10):
        // add x1, x1, x2      ; sum += counter
        mem[4]  = 32'h002080b3;
        // add x2, x2, x4      ; counter += 1
        mem[5]  = 32'h00410133;
        // ble x2, x3, LOOP    ; if counter <= limit, goto LOOP (bge x3, x2, -8)
        mem[6]  = 32'hfe21dce3; // bge x3, x2, -8
        
        // sd x1, 0(x0)        ; store sum to memory[0]
        mem[7]  = 32'h00103023;
        // ld x5, 0(x0)        ; load sum back to x5
        mem[8]  = 32'h00003283;
        // and x6, x1, x5      ; x6 = x1 & x5
        mem[9]  = 32'h0050f333;
        // or  x7, x1, x5      ; x7 = x1 | x5
        mem[10] = 32'h0050e3b3;
        // sub x8, x1, x5      ; x8 = x1 - x5 = 0
        mem[11] = 32'h40508433;

        // ================================================================
        // Test program Part 2: SHA-256 hashing of "Dinh Khanh Dang"
        // SHA-256("Dinh Khanh Dang") = 7885c9ac bb0457fe db6dc331 a549d736
        //                              375b65ef 16d9ad4b 89465cc6 d9d2b8d1
        //
        // Message "Dinh Khanh Dang" = 15 bytes = 120 bits
        // Padded 512-bit block (big-endian 32-bit words):
        //   W[0]  = 0x44696E68  ("Dinh")
        //   W[1]  = 0x204B6861  (" Kha")
        //   W[2]  = 0x6E682044  ("nh D")
        //   W[3]  = 0x616E6780  ("ang" + 0x80 padding)
        //   W[4]..W[14] = 0x00000000
        //   W[15] = 0x00000078  (120 in decimal = message bit length)
        //
        // SHA-256 accelerator address map:
        //   0x1000-0x1038: message input (8 x 64-bit)
        //   0x1040:        control (write 1 = start)
        //   0x1048:        status  (bit0 = done)
        //   0x1050-0x1068: hash output (4 x 64-bit)
        // ================================================================

        // --- Setup base address x20 = 0x1000 ---
        // lui x20, 1           ; x20 = 0x1000
        mem[12] = 32'h00001a37;    // lui x20, 1

        // --- Write W[0:1] = 0x44696E68_204B6861 ---
        // Build upper 32 bits 0x44696E68 in x21:
        // lui x21, 0x44697     ; x21 = 0x44697000
        mem[13] = 32'h44697ab7;    // lui x21, 0x44697
        // addi x21, x21, -0x398 ; x21 = 0x44696E68
        mem[14] = 32'he68a8a93;    // addi x21, x21, -408
        // slli x21, x21, 32    ; x21 = 0x44696E6800000000
        mem[15] = 32'h020a9a93;    // slli x21, x21, 32
        // Build lower 32 bits 0x204B6861 in x22:
        // lui x22, 0x204B7     ; x22 = 0x204B7000
        mem[16] = 32'h204b7b37;    // lui x22, 0x204B7
        // addi x22, x22, -0x79F ; x22 = 0x204B6861
        mem[17] = 32'h861b0b13;    // addi x22, x22, -1951
        // add x21, x21, x22   ; x21 = 0x44696E68_204B6861
        mem[18] = 32'h016a8ab3;    // add x21, x21, x22
        // sd x21, 0(x20)      ; Write W[0:1] to 0x1000
        mem[19] = 32'h015a3023;    // sd x21, 0(x20)

        // --- Write W[2:3] = 0x6E682044_616E6780 ---
        // Build upper 32 bits 0x6E682044 in x21:
        // lui x21, 0x6E682     ; x21 = 0x6E682000
        mem[20] = 32'h6e682ab7;    // lui x21, 0x6E682
        // addi x21, x21, 0x044 ; x21 = 0x6E682044
        mem[21] = 32'h044a8a93;    // addi x21, x21, 68
        // slli x21, x21, 32   ; x21 = 0x6E68204400000000
        mem[22] = 32'h020a9a93;    // slli x21, x21, 32
        // Build lower 32 bits 0x616E6780 in x22:
        // lui x22, 0x616E6     ; x22 = 0x616E6000
        mem[23] = 32'h616e6b37;    // lui x22, 0x616E6
        // addi x22, x22, 0x780 ; x22 = 0x616E6780
        mem[24] = 32'h780b0b13;    // addi x22, x22, 1920
        // add x21, x21, x22   ; x21 = 0x6E682044_616E6780
        mem[25] = 32'h016a8ab3;    // add x21, x21, x22
        // sd x21, 8(x20)      ; Write W[2:3] to 0x1008
        mem[26] = 32'h015a3423;    // sd x21, 8(x20)

        // --- Zero out W[4..13] ---
        // addi x22, x0, 0     ; x22 = 0
        mem[27] = 32'h00000b13;    // addi x22, x0, 0
        // sd x22, 16(x20)     ; W[4:5] = 0  -> 0x1010
        mem[28] = 32'h016a3823;    // sd x22, 16(x20)
        // sd x22, 24(x20)     ; W[6:7] = 0  -> 0x1018
        mem[29] = 32'h016a3c23;    // sd x22, 24(x20)
        // sd x22, 32(x20)     ; W[8:9] = 0  -> 0x1020
        mem[30] = 32'h036a3023;    // sd x22, 32(x20)
        // sd x22, 40(x20)     ; W[10:11] = 0 -> 0x1028
        mem[31] = 32'h036a3423;    // sd x22, 40(x20)
        // sd x22, 48(x20)     ; W[12:13] = 0 -> 0x1030
        mem[32] = 32'h036a3823;    // sd x22, 48(x20)

        // --- Write W[14:15]: {0x00000000, 0x00000078} ---
        // addi x22, x0, 0x78  ; x22 = 120 (bit length)
        mem[33] = 32'h07800b13;    // addi x22, x0, 0x78
        // sd x22, 56(x20)     ; Write to 0x1038
        mem[34] = 32'h036a3c23;    // sd x22, 56(x20)

        // --- Start SHA-256 ---
        // addi x24, x0, 1     ; x24 = 1
        mem[35] = 32'h00100c13;    // addi x24, x0, 1
        // sd x24, 64(x20)     ; Write 1 to control reg 0x1040
        mem[36] = 32'h058a3023;    // sd x24, 0x40(x20)

        // --- Poll status register until done ---
        // ld x25, 72(x20)     ; Read status from 0x1048
        mem[37] = 32'h048a3c83;    // ld x25, 0x48(x20)
        // beq x25, x0, -4     ; If not done, loop back
        mem[38] = 32'hfe0c8ee3;    // beq x25, x0, -4

        // --- Read hash output ---
        // ld x26, 80(x20)     ; Hash[0:1] from 0x1050 -> {H0, H1}
        mem[39] = 32'h050a3d03;    // ld x26, 0x50(x20)
        // ld x27, 88(x20)     ; Hash[2:3] from 0x1058 -> {H2, H3}
        mem[40] = 32'h058a3d83;    // ld x27, 0x58(x20)
        // ld x28, 96(x20)     ; Hash[4:5] from 0x1060 -> {H4, H5}
        mem[41] = 32'h060a3e03;    // ld x28, 0x60(x20)
        // ld x29, 104(x20)    ; Hash[6:7] from 0x1068 -> {H6, H7}
        mem[42] = 32'h068a3e83;    // ld x29, 0x68(x20)

        // --- Store hash to data memory for verification ---
        // sd x26, 64(x0)      ; Store H0:H1 to dmem[64]
        mem[43] = 32'h05a03023;    // sd x26, 0x40(x0)
        // sd x27, 72(x0)      ; Store H2:H3 to dmem[72]
        mem[44] = 32'h05b03423;    // sd x27, 0x48(x0)
        // sd x28, 80(x0)      ; Store H4:H5 to dmem[80]
        mem[45] = 32'h05c03823;    // sd x28, 0x50(x0)
        // sd x29, 88(x0)      ; Store H6:H7 to dmem[88]
        mem[46] = 32'h05d03c23;    // sd x29, 0x58(x0)

        // End: infinite loop
        // beq x0, x0, 0       ; branch to self
        mem[47] = 32'h00000063;
    end

endmodule
