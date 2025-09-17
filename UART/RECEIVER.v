module RECEIVER #(parameter DATA_WIDTH = 8 , STOP_BIT_TICKS = 16)(
    input CLK ,
    input RESET, 

    // PARITY
    input PARITY_EN,
    input PARITY_MODE,

    input RX ,                      // RX connected to TX line
    input RX_BR_TICKS , 
    output [DATA_WIDTH-1:0] RX_DATA_OUT,
    output RX_DONE,

    output reg PARITY_ERROR,
    output FRAME_ERROR,
    output OVERRUN_ERROR,

    // for test bench only for debugging ease
    output [2:0] State_dpg,
    output [$clog2(DATA_WIDTH) - 1:0] bit_idx_dpg
);

    // PARITY
    wire expected_parity;
    PARITY_CHECKER #(.DATA_WIDTH(DATA_WIDTH)) rx_parity (
        .PARITY_EN(PARITY_EN),
        .PARITY_MODE(PARITY_MODE),
        .DATA_IN(SHIFTED_DATA),
        .PARITY(expected_parity)
    );

    // FSM states
    localparam IDLE = 0 , START = 1 , DATA = 2 , PARITY = 3 , STOP = 4;

    reg [2:0] state_reg , state_next;
    reg [3:0] RX_BR_TICKS_COUNT_reg , RX_BR_TICKS_COUNT_next;
    reg [$clog2(DATA_WIDTH) - 1:0] BIT_IDX , BIT_IDX_NEXT;
    reg [DATA_WIDTH - 1:0] SHIFTED_DATA , SHIFTED_DATA_NEXT;
    reg RX_DONE_reg , RX_DONE_next;
    reg Frame_Error_reg , Frame_Error_next;
    reg Overrun_Error_reg , Overrun_Error_next;

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            state_reg <= IDLE;
            RX_BR_TICKS_COUNT_reg <= 0;
            BIT_IDX <= 0;
            SHIFTED_DATA <= 0;
            PARITY_ERROR <= 0;
            RX_DONE_reg <= 0;
            Frame_Error_reg <= 0;
            Overrun_Error_reg <= 0;
        end
        else begin
            state_reg <= state_next;
            RX_BR_TICKS_COUNT_reg <= RX_BR_TICKS_COUNT_next;
            BIT_IDX <= BIT_IDX_NEXT;
            SHIFTED_DATA <= SHIFTED_DATA_NEXT;
            RX_DONE_reg <= RX_DONE_next;
            Frame_Error_reg <= Frame_Error_next;
            Overrun_Error_reg <= Overrun_Error_next;
            
            if (PARITY_EN) begin
                PARITY_ERROR <= (state_reg == PARITY && RX_BR_TICKS && 
                                (RX_BR_TICKS_COUNT_reg == STOP_BIT_TICKS - 1) && 
                                (RX != expected_parity));
            end
            else PARITY_ERROR <= 0;
        end
    end

    // FSM LOGIC
    always @(*) begin
            // state_next = state_reg;
            // RX_BR_TICKS_COUNT_next = RX_BR_TICKS_COUNT_reg;
            // BIT_IDX_NEXT = BIT_IDX;
            // SHIFTED_DATA_NEXT = SHIFTED_DATA;
            // RX_DONE = 0;

        case (state_reg)
            IDLE: begin
                RX_DONE_next = 0;
                Frame_Error_next = 0;
                if (RX == 0) begin
                    state_next = START;
                    RX_BR_TICKS_COUNT_next = 0;
                    BIT_IDX_NEXT = 0;
                    SHIFTED_DATA_NEXT = 0;
                end
            end


            START: begin
                if (RX_BR_TICKS) begin
                    if (RX_BR_TICKS_COUNT_reg == STOP_BIT_TICKS/2 - 1) begin
                        state_next = DATA;
                        RX_BR_TICKS_COUNT_next = 0;
                    end
                    else begin
                        RX_BR_TICKS_COUNT_next = RX_BR_TICKS_COUNT_reg + 1;
                    end
                end
            end


            DATA: begin
                if (RX_BR_TICKS) begin
                    if (RX_BR_TICKS_COUNT_reg == STOP_BIT_TICKS - 1) begin
                        // RX connected to tx so we shift data to the right to take input from the transmitter
                        SHIFTED_DATA_NEXT = {RX, SHIFTED_DATA[DATA_WIDTH - 1:1]};
                        RX_BR_TICKS_COUNT_next = 0; 
                        
                        if (BIT_IDX == DATA_WIDTH - 1) begin
                            if (PARITY_EN)
                                state_next = PARITY;
                            else
                                state_next = STOP;
                        end
                        else begin
                            BIT_IDX_NEXT = BIT_IDX + 1;
                        end
                    end
                    else begin
                        RX_BR_TICKS_COUNT_next = RX_BR_TICKS_COUNT_reg + 1;
                    end
                end
            end


            PARITY: begin
                if (RX_BR_TICKS) begin
                    if (RX_BR_TICKS_COUNT_reg == STOP_BIT_TICKS - 1) begin
                        if (RX == expected_parity) begin
                            state_next = STOP;
                            RX_BR_TICKS_COUNT_next = 0;
                        end
                        else begin
                            // Frame error
                            state_next = IDLE;
                            RX_BR_TICKS_COUNT_next = 0;
                            BIT_IDX_NEXT = 0;
                        end
                    end
                    else begin
                        RX_BR_TICKS_COUNT_next = RX_BR_TICKS_COUNT_reg + 1;
                    end
                end
            end


            STOP: begin
                if (RX_BR_TICKS) begin
                    if (RX_BR_TICKS_COUNT_reg == (STOP_BIT_TICKS - 1)) begin
                            BIT_IDX_NEXT = 0;
                            state_next = IDLE;
                            RX_BR_TICKS_COUNT_next = 0;
                        if (RX == 1) begin
                            if (RX_DONE_reg == 1) begin
                                // Previous data not consumed → overrun
                                Overrun_Error_next = 1;
                            end 
                            else begin
                                RX_DONE_next = 1;
                                Overrun_Error_next = 0;
                            end
                        end
                        else begin
                            // Frame error
                            Frame_Error_next = 1;
                        end
                    end
                    else begin
                        RX_BR_TICKS_COUNT_next = RX_BR_TICKS_COUNT_reg + 1;
                    end
                end
            end


        default: begin
            state_next = IDLE;
        end

        endcase
    end

    assign RX_DATA_OUT = SHIFTED_DATA;
    assign RX_DONE = RX_DONE_reg;
    assign State_dpg = state_reg;
    assign bit_idx_dpg = BIT_IDX;
    assign FRAME_ERROR = Frame_Error_reg;
    assign OVERRUN_ERROR = Overrun_Error_reg;

endmodule