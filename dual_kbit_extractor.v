`timescale 1ns / 1ps

module dual_lod_kbit_extractor #(
    parameter WIDTH = 16,
    parameter K     = 4
)(
    input  [WIDTH-1:0]                  data,
    output reg [K-1:0]                  kbits_h,
    output reg [$clog2(WIDTH)-1:0]      pos_h,
    output reg                          valid_h,
    output reg [K-1:0]                  kbits_l,
    output reg [$clog2(WIDTH)-1:0]      pos_l,
    output reg                          valid_l
);

    integer i, j;
    reg [WIDTH-1:0] remainder;
    
    always @(*) begin
        // Default values
        valid_h = 1'b0;
        valid_l = 1'b0;
        pos_h = 0;
        pos_l = 0;
        kbits_h = 0;
        kbits_l = 0;
        remainder = 0;
        
        // First extraction (KH)
        begin : first_extraction
            for (i = WIDTH-1; i >= 0; i = i - 1) begin
                if (data[i]) begin
                    pos_h = i;
                    valid_h = 1'b1;
                    
                    // Extract first K bits
                    for (j = 0; j < K; j = j + 1) begin
                        if (pos_h >= j)
                            kbits_h[K-1-j] = data[pos_h - j];
                        else
                            kbits_h[K-1-j] = 1'b0;
                    end
                    
                    // Create remainder
                    if (pos_h >= K)
                        remainder = data & ((1 << (pos_h - K + 1)) - 1);
                    else
                        remainder = 0;
                    
                    disable first_extraction;  // This replaces 'break'
                end
            end
        end
        
        // Second extraction (KL)
        begin : second_extraction
            for (i = WIDTH-1; i >= 0; i = i - 1) begin
                if (valid_h && remainder[i]) begin
                    pos_l = i;
                    valid_l = 1'b1;
                    
                    // Extract second K bits
                    for (j = 0; j < K; j = j + 1) begin
                        if (pos_l >= j)
                            kbits_l[K-1-j] = remainder[pos_l - j];
                        else
                            kbits_l[K-1-j] = 1'b0;
                    end
                    
                    disable second_extraction;  // This replaces 'break'
                end
            end
        end
    end
endmodule