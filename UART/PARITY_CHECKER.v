module PARITY_CHECKER #(parameter DATA_WIDTH = 8)(
    input        PARITY_EN,     // Enable parity
    input        PARITY_MODE,   // 0 = Even, 1 = Odd
    input  [DATA_WIDTH - 1:0] DATA_IN, 
    output reg   PARITY         // Generated parity bit
);

    always @(*) begin
        if (PARITY_EN) begin
            case (PARITY_MODE)
                1'b0: begin
                    // Even parity = XOR reduction of DATA_IN
                    PARITY = ^DATA_IN;  
                end

                1'b1: begin
                    // Odd parity = invert of even
                    PARITY = ~(^DATA_IN); 
                end

                default: PARITY = ^DATA_IN; // default to even
            endcase
        end else begin
            PARITY = 1'b0; // parity disabled
        end
    end

endmodule
