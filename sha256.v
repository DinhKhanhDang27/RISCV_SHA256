// ============================================================================
// SHA-256 Hardware Accelerator (Memory-Mapped Peripheral)
// 
// Address Map (base = 0x1000):
//   0x1000 - 0x1038 : Message input (8 x 64-bit = 512-bit block), write-only
//   0x1040           : Control register (write 1 to start)
//   0x1048           : Status register  (read: bit0 = done)
//   0x1050 - 0x1068  : Hash output (4 x 64-bit = 256-bit), read-only
//   0x1070           : Message length in bits (for padding), write
//
// Usage:
//   1. Write 512-bit message block to 0x1000-0x1038
//   2. Write message length (in bits) to 0x1070
//   3. Write 1 to 0x1040 (start)
//   4. Poll 0x1048 until bit0 = 1 (done)
//   5. Read hash from 0x1050-0x1068
// ============================================================================
module sha256 (
    input         clk,
    input         rst,
    input         mem_read,
    input         mem_write,
    input  [63:0] addr,
    input  [63:0] write_data,
    output reg [63:0] read_data,
    output        sha_select     // active when address is in SHA range
);

    // ========================================================================
    // Address decode
    // ========================================================================
    assign sha_select = (addr[15:8] == 8'h10); // 0x1000 - 0x10FF

    wire [7:0] offset;
    assign offset = addr[7:0];

    // ========================================================================
    // Internal registers
    // ========================================================================
    // Message block: 16 x 32-bit words = 512 bits
    reg [31:0] msg [0:15];

    // Control/status
    reg        start;
    reg        done;
    reg [63:0] msg_bit_len;  // message length in bits for padding

    // Hash output: 8 x 32-bit = 256 bits
    reg [31:0] H0, H1, H2, H3, H4, H5, H6, H7;

    // ========================================================================
    // SHA-256 Constants K[0..63]
    // ========================================================================
    reg [31:0] K [0:63];
    initial begin
        K[ 0] = 32'h428a2f98; K[ 1] = 32'h71374491;
        K[ 2] = 32'hb5c0fbcf; K[ 3] = 32'he9b5dba5;
        K[ 4] = 32'h3956c25b; K[ 5] = 32'h59f111f1;
        K[ 6] = 32'h923f82a4; K[ 7] = 32'hab1c5ed5;
        K[ 8] = 32'hd807aa98; K[ 9] = 32'h12835b01;
        K[10] = 32'h243185be; K[11] = 32'h550c7dc3;
        K[12] = 32'h72be5d74; K[13] = 32'h80deb1fe;
        K[14] = 32'h9bdc06a7; K[15] = 32'hc19bf174;
        K[16] = 32'he49b69c1; K[17] = 32'hefbe4786;
        K[18] = 32'h0fc19dc6; K[19] = 32'h240ca1cc;
        K[20] = 32'h2de92c6f; K[21] = 32'h4a7484aa;
        K[22] = 32'h5cb0a9dc; K[23] = 32'h76f988da;
        K[24] = 32'h983e5152; K[25] = 32'ha831c66d;
        K[26] = 32'hb00327c8; K[27] = 32'hbf597fc7;
        K[28] = 32'hc6e00bf3; K[29] = 32'hd5a79147;
        K[30] = 32'h06ca6351; K[31] = 32'h14292967;
        K[32] = 32'h27b70a85; K[33] = 32'h2e1b2138;
        K[34] = 32'h4d2c6dfc; K[35] = 32'h53380d13;
        K[36] = 32'h650a7354; K[37] = 32'h766a0abb;
        K[38] = 32'h81c2c92e; K[39] = 32'h92722c85;
        K[40] = 32'ha2bfe8a1; K[41] = 32'ha81a664b;
        K[42] = 32'hc24b8b70; K[43] = 32'hc76c51a3;
        K[44] = 32'hd192e819; K[45] = 32'hd6990624;
        K[46] = 32'hf40e3585; K[47] = 32'h106aa070;
        K[48] = 32'h19a4c116; K[49] = 32'h1e376c08;
        K[50] = 32'h2748774c; K[51] = 32'h34b0bcb5;
        K[52] = 32'h391c0cb3; K[53] = 32'h4ed8aa4a;
        K[54] = 32'h5b9cca4f; K[55] = 32'h682e6ff3;
        K[56] = 32'h748f82ee; K[57] = 32'h78a5636f;
        K[58] = 32'h84c87814; K[59] = 32'h8cc70208;
        K[60] = 32'h90befffa; K[61] = 32'ha4506ceb;
        K[62] = 32'hbef9a3f7; K[63] = 32'hc67178f2;
    end

    // ========================================================================
    // SHA-256 Working variables and message schedule
    // ========================================================================
    reg [31:0] W [0:63];   // Message schedule
    reg [31:0] a, b, c, d, e, f, g, h;

    // State machine
    reg [2:0] state;
    localparam IDLE      = 3'd0;
    localparam PAD       = 3'd1;
    localparam INIT_HASH = 3'd2;
    localparam EXPAND    = 3'd3;
    localparam COMPRESS  = 3'd4;
    localparam FINAL     = 3'd5;

    reg [6:0] round;       // 0-63 for compression, 16-63 for expansion
    reg       expand_done;

    // ========================================================================
    // SHA-256 helper functions (combinational)
    // ========================================================================
    function [31:0] rotr;
        input [31:0] x;
        input [4:0]  n;
        rotr = (x >> n) | (x << (32 - n));
    endfunction

    function [31:0] sigma0;
        input [31:0] x;
        sigma0 = rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3);
    endfunction

    function [31:0] sigma1;
        input [31:0] x;
        sigma1 = rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10);
    endfunction

    function [31:0] Sigma0;
        input [31:0] x;
        Sigma0 = rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
    endfunction

    function [31:0] Sigma1;
        input [31:0] x;
        Sigma1 = rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
    endfunction

    function [31:0] Ch;
        input [31:0] x, y, z;
        Ch = (x & y) ^ (~x & z);
    endfunction

    function [31:0] Maj;
        input [31:0] x, y, z;
        Maj = (x & y) ^ (x & z) ^ (y & z);
    endfunction

    // ========================================================================
    // Memory-mapped register writes
    // ========================================================================
    integer idx;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            start <= 1'b0;
            msg_bit_len <= 64'd0;
            for (idx = 0; idx < 16; idx = idx + 1)
                msg[idx] <= 32'd0;
        end else begin
            start <= 1'b0;  // auto-clear

            if (mem_write && sha_select) begin
                case (offset)
                    // Message block: 0x00-0x3F (big-endian 32-bit words packed in 64-bit)
                    8'h00: begin
                        msg[0]  <= write_data[63:32];
                        msg[1]  <= write_data[31:0];
                    end
                    8'h08: begin
                        msg[2]  <= write_data[63:32];
                        msg[3]  <= write_data[31:0];
                    end
                    8'h10: begin
                        msg[4]  <= write_data[63:32];
                        msg[5]  <= write_data[31:0];
                    end
                    8'h18: begin
                        msg[6]  <= write_data[63:32];
                        msg[7]  <= write_data[31:0];
                    end
                    8'h20: begin
                        msg[8]  <= write_data[63:32];
                        msg[9]  <= write_data[31:0];
                    end
                    8'h28: begin
                        msg[10] <= write_data[63:32];
                        msg[11] <= write_data[31:0];
                    end
                    8'h30: begin
                        msg[12] <= write_data[63:32];
                        msg[13] <= write_data[31:0];
                    end
                    8'h38: begin
                        msg[14] <= write_data[63:32];
                        msg[15] <= write_data[31:0];
                    end
                    // Control: start
                    8'h40: begin
                        start <= write_data[0];
                    end
                    // Message bit length
                    8'h70: begin
                        msg_bit_len <= write_data;
                    end
                    default: ;
                endcase
            end
        end
    end

    // ========================================================================
    // Memory-mapped register reads
    // ========================================================================
    always @(*) begin
        read_data = 64'd0;
        if (mem_read && sha_select) begin
            case (offset)
                // Status register
                8'h48: read_data = {63'd0, done};
                // Hash output (big-endian, 2 words per 64-bit read)
                8'h50: read_data = {H0, H1};
                8'h58: read_data = {H2, H3};
                8'h60: read_data = {H4, H5};
                8'h68: read_data = {H6, H7};
                default: read_data = 64'd0;
            endcase
        end
    end

    // ========================================================================
    // SHA-256 Core State Machine
    // Processes one 512-bit block with automatic padding for single-block messages
    // ========================================================================
    reg [31:0] T1, T2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done  <= 1'b0;
            round <= 7'd0;
            expand_done <= 1'b0;
            H0 <= 32'd0; H1 <= 32'd0; H2 <= 32'd0; H3 <= 32'd0;
            H4 <= 32'd0; H5 <= 32'd0; H6 <= 32'd0; H7 <= 32'd0;
        end else begin
            case (state)
                // --------------------------------------------------------
                IDLE: begin
                    if (start) begin
                        done  <= 1'b0;
                        state <= PAD;
                    end
                end

                // --------------------------------------------------------
                // Padding: copy message, add 0x80 byte, add length
                // For messages <= 55 bytes, fits in one 512-bit block
                PAD: begin
                    // Copy first 16 words from message register as-is
                    // The CPU is responsible for padding:
                    //   - Write message bytes in big-endian
                    //   - Append 0x80 after last byte
                    //   - Zero fill
                    //   - Write bit-length to last 64 bits (msg[14], msg[15])
                    // 
                    // W[0..15] = msg[0..15] (already set by CPU)
                    // Initialize hash values
                    state <= INIT_HASH;
                end

                // --------------------------------------------------------
                INIT_HASH: begin
                    // SHA-256 initial hash values
                    H0 <= 32'h6a09e667;
                    H1 <= 32'hbb67ae85;
                    H2 <= 32'h3c6ef372;
                    H3 <= 32'ha54ff53a;
                    H4 <= 32'h510e527f;
                    H5 <= 32'h9b05688c;
                    H6 <= 32'h1f83d9ab;
                    H7 <= 32'h5be0cd19;

                    // Load initial W[0..15] from message
                    W[0]  <= msg[0];
                    W[1]  <= msg[1];
                    W[2]  <= msg[2];
                    W[3]  <= msg[3];
                    W[4]  <= msg[4];
                    W[5]  <= msg[5];
                    W[6]  <= msg[6];
                    W[7]  <= msg[7];
                    W[8]  <= msg[8];
                    W[9]  <= msg[9];
                    W[10] <= msg[10];
                    W[11] <= msg[11];
                    W[12] <= msg[12];
                    W[13] <= msg[13];
                    W[14] <= msg[14];
                    W[15] <= msg[15];

                    round <= 7'd16;
                    expand_done <= 1'b0;
                    state <= EXPAND;
                end

                // --------------------------------------------------------
                // Message schedule expansion: W[16..63]
                EXPAND: begin
                    if (round < 7'd64) begin
                        W[round[5:0]] <= sigma1(W[round[5:0] - 2]) + W[round[5:0] - 7] +
                                         sigma0(W[round[5:0] - 15]) + W[round[5:0] - 16];
                        round <= round + 7'd1;
                    end else begin
                        // Initialize working variables
                        a <= H0; b <= H1; c <= H2; d <= H3;
                        e <= H4; f <= H5; g <= H6; h <= H7;
                        round <= 7'd0;
                        state <= COMPRESS;
                    end
                end

                // --------------------------------------------------------
                // Compression: 64 rounds
                COMPRESS: begin
                    if (round < 7'd64) begin
                        T1 = h + Sigma1(e) + Ch(e, f, g) + K[round[5:0]] + W[round[5:0]];
                        T2 = Sigma0(a) + Maj(a, b, c);
                        h <= g;
                        g <= f;
                        f <= e;
                        e <= d + T1;
                        d <= c;
                        c <= b;
                        b <= a;
                        a <= T1 + T2;
                        round <= round + 7'd1;
                    end else begin
                        state <= FINAL;
                    end
                end

                // --------------------------------------------------------
                // Add compressed chunk to hash
                FINAL: begin
                    H0 <= H0 + a;
                    H1 <= H1 + b;
                    H2 <= H2 + c;
                    H3 <= H3 + d;
                    H4 <= H4 + e;
                    H5 <= H5 + f;
                    H6 <= H6 + g;
                    H7 <= H7 + h;
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
