// ============================================================================
// SHA-256 Standalone Test - Direct module test bypassing RISC-V
// ============================================================================
`timescale 1ns / 1ps

module sha256_test;
    reg         clk;
    reg         rst;
    reg         mem_read;
    reg         mem_write;
    reg  [63:0] addr;
    reg  [63:0] write_data;
    wire [63:0] read_data;
    wire        sha_select;

    sha256 dut (
        .clk(clk), .rst(rst),
        .mem_read(mem_read), .mem_write(mem_write),
        .addr(addr), .write_data(write_data),
        .read_data(read_data), .sha_select(sha_select)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task write_sha(input [7:0] off, input [63:0] data);
        begin
            @(posedge clk);
            addr = {56'd0, off} + 64'h1000;
            write_data = data;
            mem_write = 1;
            mem_read = 0;
            @(posedge clk);
            mem_write = 0;
        end
    endtask

    task read_sha(input [7:0] off, output [63:0] data);
        begin
            @(posedge clk);
            addr = {56'd0, off} + 64'h1000;
            mem_write = 0;
            mem_read = 1;
            #1;
            data = read_data;
            @(posedge clk);
            mem_read = 0;
        end
    endtask

    reg [63:0] rdata;
    integer i;

    initial begin
        rst = 1; mem_read = 0; mem_write = 0;
        addr = 0; write_data = 0;
        #20;
        rst = 0;
        #10;

        $display("=== SHA-256 Standalone Test ===");
        $display("Input: \"Dinh Khanh Dang\" (0x44696e68204b68616e682044616e67)");
        
        // --- 1. Nạp Message W[0..3] ---
        // W[0:1] = "Dinh Kha"
        write_sha(8'h00, 64'h44696E68_204B6861);
        // W[2:3] = "nh Dang" + 0x80 padding
        write_sha(8'h08, 64'h6E682044_616E6780);

        // --- 2. Nạp Zero padding W[4..13] ---
        write_sha(8'h10, 64'h00000000_00000000);
        write_sha(8'h18, 64'h00000000_00000000);
        write_sha(8'h20, 64'h00000000_00000000);
        write_sha(8'h28, 64'h00000000_00000000);
        write_sha(8'h30, 64'h00000000_00000000);

        // --- 3. Nạp Bit length W[14:15] ---
        // 120 bits = 0x78
        write_sha(8'h38, 64'h00000000_00000078);

        // --- 4. Kích hoạt Start SHA-256 ---
        write_sha(8'h40, 64'h1);

        // Wait for completion
        repeat(200) @(posedge clk);

        $display("SHA-256 State = %0d", dut.state);
        $display("SHA-256 Done  = %b", dut.done);
        $display("");

        $display("Hash output:");
        $display("  H0 = %08h", dut.H0);
        $display("  H1 = %08h", dut.H1);
        $display("  H2 = %08h", dut.H2);
        $display("  H3 = %08h", dut.H3);
        $display("  H4 = %08h", dut.H4);
        $display("  H5 = %08h", dut.H5);
        $display("  H6 = %08h", dut.H6);
        $display("  H7 = %08h", dut.H7);
        $display("");

        // Show some W values for debugging
        $display("Message schedule W[0..15]:");
        for (i = 0; i < 16; i = i + 1)
            $display("  W[%0d] = %08h", i, dut.W[i]);
        $display("");
        $display("Message schedule W[16..63]:");
        for (i = 16; i < 64; i = i + 1)
            $display("  W[%0d] = %08h", i, dut.W[i]);

        // Display working variables
        $display("");
        $display("Working variables after compression:");
        $display("  a = %08h", dut.a);
        $display("  b = %08h", dut.b);
        $display("  c = %08h", dut.c);
        $display("  d = %08h", dut.d);
        $display("  e = %08h", dut.e);
        $display("  f = %08h", dut.f);
        $display("  g = %08h", dut.g);
        $display("  h = %08h", dut.h);

        $stop;
    end
endmodule