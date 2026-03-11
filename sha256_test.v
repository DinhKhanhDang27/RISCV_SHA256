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
        $display("Expected: 7885c9ac bb0457fe db6dc331 a549d736");
        $display("          375b65ef 16d9ad4b 89465cc6 d9d2b8d1");
        $display("");

        // SHA-256 padded message for "Dinh Khanh Dang" (15 bytes = 120 bits):
        // W[0]=0x44696E68 W[1]=0x204B6861 W[2]=0x6E682044 W[3]=0x616E6780
        // W[4..14]=0x00000000 W[15]=0x00000078
        // As 64-bit writes (big-endian pair):
        write_sha(8'h00, 64'h44696E68204B6861);  // W[0]="Dinh", W[1]=" Kha"
        write_sha(8'h08, 64'h6E682044616E6780);  // W[2]="nh D", W[3]="ang"+pad
        write_sha(8'h10, 64'h0000000000000000);  // W[4], W[5]
        write_sha(8'h18, 64'h0000000000000000);  // W[6], W[7]
        write_sha(8'h20, 64'h0000000000000000);  // W[8], W[9]
        write_sha(8'h28, 64'h0000000000000000);  // W[10], W[11]
        write_sha(8'h30, 64'h0000000000000000);  // W[12], W[13]
        write_sha(8'h38, 64'h0000000000000078);  // W[14]=0, W[15]=0x78 (120 bits)

        // Display message words
        $display("Message words:");
        for (i = 0; i < 16; i = i + 1)
            $display("  msg[%0d] = %08h", i, dut.msg[i]);
        $display("");

        // Start
        write_sha(8'h40, 64'h1);

        // Wait for completion
        repeat(200) @(posedge clk);

        $display("SHA-256 State = %0d (expect 0=IDLE)", dut.state);
        $display("SHA-256 Done  = %b", dut.done);
        $display("");

        $display("Hash output:");
        $display("  H0 = %08h  (expect 7885c9ac)", dut.H0);
        $display("  H1 = %08h  (expect bb0457fe)", dut.H1);
        $display("  H2 = %08h  (expect db6dc331)", dut.H2);
        $display("  H3 = %08h  (expect a549d736)", dut.H3);
        $display("  H4 = %08h  (expect 375b65ef)", dut.H4);
        $display("  H5 = %08h  (expect 16d9ad4b)", dut.H5);
        $display("  H6 = %08h  (expect 89465cc6)", dut.H6);
        $display("  H7 = %08h  (expect d9d2b8d1)", dut.H7);
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

        if (dut.H0 == 32'h7885c9ac && dut.H1 == 32'hbb0457fe &&
            dut.H2 == 32'hdb6dc331 && dut.H3 == 32'ha549d736 &&
            dut.H4 == 32'h375b65ef && dut.H5 == 32'h16d9ad4b &&
            dut.H6 == 32'h89465cc6 && dut.H7 == 32'hd9d2b8d1)
            $display("\nPASS: SHA-256 hash matches!");
        else
            $display("\nFAIL: SHA-256 hash does NOT match!");

        $stop;
    end
endmodule
