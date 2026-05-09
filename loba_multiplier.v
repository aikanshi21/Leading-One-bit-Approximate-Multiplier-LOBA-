`timescale 1ns / 1ps

module loba_multiplier #(
    parameter WIDTH = 16,   // Operand width
    parameter K     = 4,    // Small multiplier width (K <= WIDTH/4)
    parameter MODE  = 3     // 0: LoBA0, 1: LoBA1, 2: LoBA2, 3: LoBA3
)(
    input [WIDTH-1:0]      A,
    input [WIDTH-1:0]      B,
    output [2*WIDTH-1:0]    P      // Approximate product
);

    // Internal signals
    wire [K-1:0] A_KH, A_KL, B_KH, B_KL;
    wire [$clog2(WIDTH)-1:0] k_a1, k_a2, k_b1, k_b2;
    wire valid_a1, valid_b1, valid_a2, valid_b2;
    
    // Shift amounts (2K-2 = 6 when K=4)
    wire [2*$clog2(WIDTH)-1:0] K1, K2, K3, K4;
    
    // Small multiplier outputs
    wire [2*K-1:0] prod_KHxKH, prod_KHxKL, prod_KLxKH, prod_KLxKL;
    
    // Shifted partial products
    wire [2*WIDTH-1:0] PP0, PP1, PP2, PP3;
    
    //----------------------------------------------------------------
    // Extract A_KH, A_KL and B_KH, B_KL using dual extractors
    //----------------------------------------------------------------
    dual_lod_kbit_extractor #(WIDTH, K) extract_A (
        .data(A),
        .kbits_h(A_KH), .pos_h(k_a1), .valid_h(valid_a1),
        .kbits_l(A_KL), .pos_l(k_a2), .valid_l(valid_a2)
    );
    
    dual_lod_kbit_extractor #(WIDTH, K) extract_B (
        .data(B),
        .kbits_h(B_KH), .pos_h(k_b1), .valid_h(valid_b1),
        .kbits_l(B_KL), .pos_l(k_b2), .valid_l(valid_b2)
    );
    
    //----------------------------------------------------------------
    // Small K x K multipliers (combinational)
    //----------------------------------------------------------------
    assign prod_KHxKH = A_KH * B_KH;
    assign prod_KHxKL = A_KH * B_KL;
    assign prod_KLxKH = A_KL * B_KH;
    assign prod_KLxKL = A_KL * B_KL;
    
    //----------------------------------------------------------------
    // Shift amount calculation
    // K1 = k_a1 + k_b1 - (2K-2)
    // K2 = k_a1 + k_b2 - (2K-2)
    // K3 = k_a2 + k_b1 - (2K-2)
    // K4 = k_a2 + k_b2 - (2K-2)
    //----------------------------------------------------------------
    localparam SHIFT = 2*K - 2;
    
    assign K1 = (valid_a1 && valid_b1) ? (k_a1 + k_b1 - SHIFT) : 0;
    assign K2 = (valid_a1 && valid_b2) ? (k_a1 + k_b2 - SHIFT) : 0;
    assign K3 = (valid_a2 && valid_b1) ? (k_a2 + k_b1 - SHIFT) : 0;
    assign K4 = (valid_a2 && valid_b2) ? (k_a2 + k_b2 - SHIFT) : 0;
    
    //----------------------------------------------------------------
    // Barrel shifter function (left shift by variable amount)
    //----------------------------------------------------------------
    function [2*WIDTH-1:0] shift_left;
        input [2*K-1:0] value;
        input [2*$clog2(WIDTH)-1:0] shift;
        integer s;
        begin
            shift_left = 0;
            if (shift < 2*WIDTH) begin
                for (s = 0; s < 2*K; s = s + 1) begin
                    if (value[s])
                        shift_left[s + shift] = 1'b1;
                end
            end
        end
    endfunction
    
    // Apply shifts to partial products
    assign PP0 = shift_left(prod_KHxKH, K1);
    assign PP1 = shift_left(prod_KHxKL, K2);
    assign PP2 = shift_left(prod_KLxKH, K3);
    assign PP3 = shift_left(prod_KLxKL, K4);
    
    //----------------------------------------------------------------
    // Final product based on MODE
    //----------------------------------------------------------------
    reg [2*WIDTH-1:0] sum;
    
    always @(*) begin
        case (MODE)
            0: sum = PP0;                                    // LoBA0
            1: sum = PP0 + PP1;                              // LoBA1
            2: sum = PP0 + PP1 + PP2;                        // LoBA2
            3: sum = PP0 + PP1 + PP2 + PP3;                  // LoBA3
            default: sum = PP0;
        endcase
    end
    
    assign P = sum;
    
endmodule