module UART #(parameter DATA_WIDTH = 8)(
    input clk , reset,

    //PARITY
    input PARITY_EN,
    input PARITY_MODE,

    // Receiver
    input RX ,
    output [DATA_WIDTH-1:0] RX_DATA_OUT,
    output RX_DONE,
    
    output PARITY_ERROR,
    output Frame_Error,
    output Overrun_Error,

    // RX_FIFO
    // input [DATA_WIDTH-1:0] RX_FIFO_DATA_IN,
    // input RX_FIFO_WR_EN,
    input RX_FIFO_RD_EN,
    output RX_FIFO_FULL, RX_FIFO_EMPTY,
    output [DATA_WIDTH-1:0] RX_FIFO_DATA_OUT,

    // Transmitter
    // input TX_START,
    // input [DATA_WIDTH-1:0] TX_DATA_IN,
    output TX , TX_DONE,

    // TX_FIFO
    input [DATA_WIDTH-1:0] TX_FIFO_DATA_IN,
    input TX_WR_EN,
    // input TX_RD_EN,
    output TX_FIFO_FULL, TX_FIFO_EMPTY,
    output [DATA_WIDTH-1:0] TX_FIFO_DATA_OUT,

    // BR GEN
    input [3:0] UBRRL,
    output BR_GEN_TICK
);  

    // BR GEN
    BaudRateGen #(.CLOCK_FREQ(50_000_000)) BR_GEN_INST(
        .clk(clk) , 
        .reset(reset) , 
        .UBRRL(UBRRL) ,
        .BR_GEN_TICK(BR_GEN_TICK)
    );

    // Receiver
    RECEIVER #(.DATA_WIDTH(DATA_WIDTH) , .STOP_BIT_TICKS(16)) RECEIVER_INST(
        .CLK(clk) , 
        .RESET(reset) , 
        
        .PARITY_EN(PARITY_EN) ,
        .PARITY_MODE(PARITY_MODE) ,

        .RX(RX) , 
        .RX_BR_TICKS(BR_GEN_TICK) , 
        .RX_DATA_OUT(RX_DATA_OUT),
        .RX_DONE(RX_DONE),

        .PARITY_ERROR(PARITY_ERROR),
        .FRAME_ERROR(Frame_Error),
        .OVERRUN_ERROR(Overrun_Error),

        // for test bench only for debugging ease
        .State_dpg(),
        .bit_idx_dpg()
    );


    // Receiver FIFO
    // assign RX_FIFO_WR_EN = RX_DONE;
    // assign RX_FIFO_DATA_IN = RX_DATA_OUT;

    fifo_generator_0 RX_FIFO (
        .clk(clk),      // input wire clk
        .srst(reset),    // input wire srst
        .din(RX_DATA_OUT),      // input wire [7 : 0] din
        .wr_en(RX_DONE),  // input wire wr_en
        .rd_en(RX_FIFO_RD_EN),  // input wire rd_en
        .dout(RX_FIFO_DATA_OUT),    // output wire [7 : 0] dout
        .full(RX_FIFO_FULL),    // output wire full
        .empty(RX_FIFO_EMPTY)  // output wire empty
    );
    

    // Transmitter
    TRANSMITTER #(.DATA_WIDTH(DATA_WIDTH) , .STOP_BIT_TICKS(16)) TRANSMITTER_INST(
        .CLK(clk) ,
        .RESET(reset) , 

        .PARITY_EN(PARITY_EN) ,
        .PARITY_MODE(PARITY_MODE) ,

        .TX_BR_TICKS(BR_GEN_TICK) , 
        .TX_START(~TX_FIFO_EMPTY) , 
        .TX_DATA_IN(TX_FIFO_DATA_OUT),
        .TX(TX) , 
        .TX_DONE(TX_DONE),

        // for test bench only for debugging ease
        .State_dpg(),
        .bit_idx_dpg()
    );


    fifo_generator_0 TX_FIFO (
        .clk(clk),      // input wire clk
        .srst(reset),    // input wire srst
        .din(TX_FIFO_DATA_IN),      // input wire [7 : 0] din
        .wr_en(TX_WR_EN),  // input wire wr_en
        .rd_en(TX_DONE),  // input wire rd_en
        .dout(TX_FIFO_DATA_OUT),    // output wire [7 : 0] dout
        .full(TX_FIFO_FULL),    // output wire full
        .empty(TX_FIFO_EMPTY)  // output wire empty
    );


endmodule