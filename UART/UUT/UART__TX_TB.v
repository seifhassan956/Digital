`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/13/2025 08:57:43 AM
// Design Name: 
// Module Name: UART_TB
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module UART_TX_TB(
    );

    // Parameters
    localparam DATA_WIDTH = 8;
    localparam STOP_BIT_TICKS = 16;

    // Clock and reset
    reg clk;
    reg reset;

    // Baud tick
    wire br_tick;     // baudrate tick

    // FIFO signals
    reg [DATA_WIDTH-1:0] tx_fifo_data_in;
    reg tx_wr_en;
    wire tx_fifo_full;
    wire tx_fifo_empty;
    wire [DATA_WIDTH-1:0] tx_fifo_data_out;

    // UART transmitter signals
    reg parity_en;
    reg parity_mode; // 0 = even, 1 = odd
    wire tx;
    wire tx_done;
    wire [2:0] State_dpg;
    wire [$clog2(DATA_WIDTH) - 1:0] Bit_idx_dpg;

    // -------------------------------
    // Baudrate generator instance
    // -------------------------------
    reg [3:0] ubrl;

    BaudRateGen #(.CLOCK_FREQ(50_000_000)) BR_GEN_INST (
        .clk(clk),
        .reset(reset),
        .UBRRL(ubrl),
        .BR_GEN_TICK(br_tick)
    );

    // -------------------------------
    // TRANSMITTER instantiation
    // -------------------------------
    TRANSMITTER #(.DATA_WIDTH(DATA_WIDTH), .STOP_BIT_TICKS(STOP_BIT_TICKS)) DUT_TX (
        .CLK(clk),
        .RESET(reset),

        .PARITY_EN(parity_en),
        .PARITY_MODE(parity_mode),
        
        .TX_BR_TICKS(br_tick),
        .TX_START(~tx_fifo_empty),
        .TX_DATA_IN(tx_fifo_data_out),
        .TX(tx),
        .TX_DONE(tx_done),
        .State_dpg(State_dpg),
        .bit_idx_dpg(Bit_idx_dpg)
    );

    fifo_generator_0 TX_FIFO (
        .clk(clk),
        .srst(reset),
        .din(tx_fifo_data_in),
        .wr_en(tx_wr_en),
        .rd_en(tx_done),
        .dout(tx_fifo_data_out),
        .full(tx_fifo_full),
        .empty(tx_fifo_empty)
    );


    //CLK
    initial begin
        clk = 0;
        forever #10 clk = ~clk;   // 20 ns period = 50 MHz clock
    end

    // -------------------------------
    // SIMULATION
    // -------------------------------
    initial begin
        reset = 1;
        parity_en = 0;
        parity_mode = 0;
        tx_wr_en = 0;
        tx_fifo_data_in = 0;
        ubrl = 4'b0000;   // 9600 baud

        #15; 
        reset = 0;

        // Write some bytes
        #100 write_byte(8'h55);
        #100 write_byte(8'hA5);

        #2000000; 
        $stop;
    end

    // -------------------------------
    // Task to write into FIFO
    // -------------------------------
    task write_byte(input [DATA_WIDTH - 1:0] data);
    begin
        @(posedge clk);
            tx_fifo_data_in <= data;
            tx_wr_en <= 1;

        @(posedge clk);
            tx_wr_en <= 0;
    end
    endtask

    // -------------------------------
    // Monitor
    // -------------------------------
    function [80*8:1] state_name;
        input [2:0] state;
        begin
            case(state)
                3'b000: state_name = "IDLE ";
                3'b001: state_name = "START";
                3'b010: state_name = "DATA ";
                3'b011: state_name = "Parity";
                3'b100: state_name = "STOP ";
                default: state_name = "UNDEF";
            endcase
        end
    endfunction

    initial begin
        $monitor("T=%0t TX=%b TX_DONE=%b FIFO_EMPTY=%b STATE=%s",
                $time, tx, tx_done, tx_fifo_empty, state_name(State_dpg));
    end


endmodule
