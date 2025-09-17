module BaudRateGen #(parameter CLOCK_FREQ = 50_000_000)(
    input clk , reset ,
    input [3:0] UBRRL ,             // Baud Rate Register
    output reg BR_GEN_TICK
);  

    reg [31:0] BAUD_RATE;
    reg [31:0] DIVISOR;
    reg [31:0] TIMER;

    always @(*) begin
        case (UBRRL)
            4'b0000: BAUD_RATE = 9600;
            4'b0001: BAUD_RATE = 19200;
            4'b0010: BAUD_RATE = 38400;
            4'b0011: BAUD_RATE = 57600;
            4'b0100: BAUD_RATE = 115200;
            4'b0101: BAUD_RATE = 230400;
            4'b0110: BAUD_RATE = 460800;
            4'b0111: BAUD_RATE = 921600;

            default: BAUD_RATE = 115200; // fallback
        endcase
    end


    localparam SAMPLE_RATE = 16;

    always @(*) begin
        DIVISOR = CLOCK_FREQ / (BAUD_RATE * SAMPLE_RATE);
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            TIMER <= 0;
            BR_GEN_TICK <= 0;
        end
        else begin
            if (TIMER == DIVISOR - 1) begin
                TIMER <= 0;
                BR_GEN_TICK <= 1;  
            end else begin
                TIMER <= TIMER + 1;
                BR_GEN_TICK <= 0;
            end
        end
    end

endmodule