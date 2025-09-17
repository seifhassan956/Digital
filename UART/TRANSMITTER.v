module TRANSMITTER #(parameter DATA_WIDTH = 8 , STOP_BIT_TICKS = 16)(
    input CLK ,
    input RESET,
    
    // PARITY
    input PARITY_EN,
    input PARITY_MODE,

    input TX_BR_TICKS ,
    input TX_START, 
    input [DATA_WIDTH-1:0] TX_DATA_IN,
    output TX , 
    output TX_DONE,

    // for test bench only for debugging ease
    output [2:0] State_dpg,
    output [$clog2(DATA_WIDTH) - 1:0] bit_idx_dpg
);
    
    // PARITY CHECKER
    wire parity_bit;
    PARITY_CHECKER #(.DATA_WIDTH(DATA_WIDTH)) TX_parity (
        .PARITY_EN(PARITY_EN),
        .PARITY_MODE(PARITY_MODE),
        .DATA_IN(TX_DATA_IN),
        .PARITY(parity_bit)
    );

    localparam IDLE = 0 , START = 1 , DATA = 2 , PARITY = 3 , STOP = 4;

    reg [2:0] state_reg , state_next;
    reg [3:0] TX_BR_TICKS_COUNT_reg , TX_BR_TICKS_COUNT_next;
    reg [$clog2(DATA_WIDTH) - 1:0] BIT_IDX , BIT_IDX_NEXT;
    reg [DATA_WIDTH - 1:0] SHIFTED_DATA , SHIFTED_DATA_NEXT;
    reg TX_reg , TX_next;
    reg TX_DONE_reg, TX_DONE_next;

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            state_reg <= IDLE;
            TX_BR_TICKS_COUNT_reg <= 0;
            BIT_IDX <= 0;
            SHIFTED_DATA <= 0;
            TX_reg <= 1;
            TX_DONE_reg <= 0;
        end
        else begin
            state_reg <= state_next;
            TX_BR_TICKS_COUNT_reg <= TX_BR_TICKS_COUNT_next;
            BIT_IDX <= BIT_IDX_NEXT;
            SHIFTED_DATA <= SHIFTED_DATA_NEXT;
            TX_reg <= TX_next;
            TX_DONE_reg <= TX_DONE_next;
        end
    end

    // FSM LOGIC
   always @(*)
    begin
        // state_next = state_reg;
        // TX_BR_TICKS_COUNT_next = TX_BR_TICKS_COUNT_reg;
        // BIT_IDX_NEXT = BIT_IDX;
        // SHIFTED_DATA_NEXT = SHIFTED_DATA;
        // TX_next = TX_reg;
        // TX_DONE_next = 0;

        case (state_reg)
            IDLE: begin
                TX_next = 1;
                TX_DONE_next = 0;
                if (TX_START) begin
                    TX_BR_TICKS_COUNT_next = 0;
                    SHIFTED_DATA_NEXT = TX_DATA_IN;
                    state_next = START;
                end
            end

            START: begin
                TX_next = 0;
                if (TX_BR_TICKS) begin
                    if (TX_BR_TICKS_COUNT_reg == STOP_BIT_TICKS - 1) begin
                        TX_BR_TICKS_COUNT_next = 0;
                        BIT_IDX_NEXT = 0;
                        state_next = DATA;
                    end
                    else
                        TX_BR_TICKS_COUNT_next = TX_BR_TICKS_COUNT_reg + 1;
                end
            end

            DATA: begin
                TX_next = SHIFTED_DATA[0];
                if (TX_BR_TICKS) begin
                    if (TX_BR_TICKS_COUNT_reg == (STOP_BIT_TICKS - 1)) begin
                        TX_BR_TICKS_COUNT_next = 0;
                        SHIFTED_DATA_NEXT = SHIFTED_DATA >> 1; // shift data bit to rx of controller 2
                        if (BIT_IDX == (DATA_WIDTH - 1))
                            if (PARITY_EN)
                                state_next = PARITY;   // go to parity if enabled
                            else
                                state_next = STOP;     // skip parity
                        else
                            BIT_IDX_NEXT = BIT_IDX + 1;
                    end
                    else
                        TX_BR_TICKS_COUNT_next = TX_BR_TICKS_COUNT_reg + 1;
                end
            end

            PARITY: begin
                TX_next = parity_bit;
                if (TX_BR_TICKS) begin
                    if (TX_BR_TICKS_COUNT_reg == (STOP_BIT_TICKS - 1)) begin
                        TX_BR_TICKS_COUNT_next = 0;
                        state_next = STOP;
                    end
                    else
                        TX_BR_TICKS_COUNT_next = TX_BR_TICKS_COUNT_reg + 1;
                end
            end

            STOP: begin
            TX_next = 1;
            if (TX_BR_TICKS) begin
                if (TX_BR_TICKS_COUNT_reg == (STOP_BIT_TICKS - 1)) begin
                    TX_DONE_next = 1;
                    state_next = IDLE;
                    TX_BR_TICKS_COUNT_next = 0;
                end
                else
                    TX_BR_TICKS_COUNT_next = TX_BR_TICKS_COUNT_reg + 1;
            end
        end

            default: begin
                state_next = IDLE;
            end
        endcase
    end

    // OUTPUT
    assign TX = TX_reg;
    assign TX_DONE = TX_DONE_reg;
    assign State_dpg = state_reg;
    assign bit_idx_dpg = BIT_IDX;

endmodule