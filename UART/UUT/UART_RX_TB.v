`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/14/2025 04:11:13 PM
// Design Name: 
// Module Name: UART_RX_TB
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: UART Receiver Testbench with FIFO integration
// 
//////////////////////////////////////////////////////////////////////////////////

module UART_RX_TB();

    // Parameters
    localparam DATA_WIDTH     = 8;
    localparam STOP_BIT_TICKS = 16;

    // Clock and reset
    reg clk;
    reg reset;

    // Baud tick
    wire br_tick;     // baudrate tick

    // FIFO signals
    reg RX_FIFO_RD_EN;
    wire [DATA_WIDTH-1:0] RX_FIFO_DATA_OUT;
    wire RX_FIFO_FULL;
    wire RX_FIFO_EMPTY;

    // UART RX signals
    reg RX;
    reg parity_en;
    reg parity_mode; 
    wire [DATA_WIDTH-1:0] rx_data_out;
    wire rx_done;
    wire parity_error;
    wire frame_error;
    wire overrun_error;
    wire [2:0] State_dpg;
    wire [$clog2(DATA_WIDTH)-1:0] Bit_idx_dpg;

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
    // RECEIVER instantiation
    // -------------------------------
    RECEIVER #(.DATA_WIDTH(DATA_WIDTH), .STOP_BIT_TICKS(STOP_BIT_TICKS)) DUT_RX (
        .CLK(clk),
        .RESET(reset),

        .PARITY_EN(parity_en),
        .PARITY_MODE(parity_mode),

        .RX(RX),
        .RX_BR_TICKS(br_tick),
        .RX_DATA_OUT(rx_data_out),
        .RX_DONE(rx_done),
        .PARITY_ERROR(parity_error),
        .Frame_Error(frame_error),
        .OVERRUN_ERROR(overrun_error),

        .State_dpg(State_dpg),
        .bit_idx_dpg(Bit_idx_dpg)
    );

    // -------------------------------
    // Receiver FIFO
    // -------------------------------
    fifo_generator_0 RX_FIFO (
        .clk(clk),
        .srst(reset),
        .din(rx_data_out),
        .wr_en(rx_done),
        .rd_en(RX_FIFO_RD_EN),
        .dout(RX_FIFO_DATA_OUT),
        .full(RX_FIFO_FULL),
        .empty(RX_FIFO_EMPTY)
    );

    // -------------------------------
    // Clock generation
    // -------------------------------
    initial begin
        clk = 0;
        forever #10 clk = ~clk;   // 20 ns period = 50 MHz
    end

    // -------------------------------
    // Simulation
    // -------------------------------
    initial begin
        reset       = 1;
        parity_en   = 0;
        parity_mode = 0;
        RX          = 1;       // idle line is high
        ubrl        = 4'b0000; // 9600 baud
        RX_FIFO_RD_EN = 0;

        #15;
        reset = 0;

        // Send a byte (UART frame) serially
        #200 send_byte(8'h55);  // 01010101
        #1000000 send_byte(8'hA5);  // 10100101

        #2000000;
        $stop;
    end

    // -------------------------------
    // Task to send a UART frame on RX line
    // -------------------------------
    task send_byte(input [DATA_WIDTH-1:0] data);
        integer i;
        integer tick_count;
        begin
            // Start bit
            RX <= 0;
            tick_count = 0;
            while (tick_count < STOP_BIT_TICKS) begin
                @(posedge clk);
                if (br_tick) tick_count = tick_count + 1;
            end

            // Data bits (LSB first, same as transmitter)
            for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                RX <= data[i];
                tick_count = 0;
                while (tick_count < STOP_BIT_TICKS) begin
                    @(posedge clk);
                    if (br_tick) tick_count = tick_count + 1;
                end
            end

            // Stop bit
            RX <= 1;
            tick_count = 0;
            while (tick_count < STOP_BIT_TICKS) begin
                @(posedge clk);
                if (br_tick) tick_count = tick_count + 1;
            end
        end
    endtask

    // -------------------------------
    // FIFO Reader Process
    // -------------------------------
    initial begin
        wait (!reset);
        forever begin
            @(posedge clk);
            if (!RX_FIFO_EMPTY) begin
                RX_FIFO_RD_EN <= 1;
                @(posedge clk);
                RX_FIFO_RD_EN <= 0;
                $display("T=%0t READ_FROM_FIFO: %h", $time, RX_FIFO_DATA_OUT);
            end
        end
    end

    // -------------------------------
    // Monitor for debug signals
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
        $monitor("T=%0t RX=%b RX_DONE=%b RAW=%h FIFO_OUT=%h FIFO_EMPTY=%b FIFO_FULL=%b PARITY_ERR=%b STATE=%s BITIDX=%0d",
                 $time, RX, rx_done, rx_data_out, RX_FIFO_DATA_OUT,
                 RX_FIFO_EMPTY, RX_FIFO_FULL, parity_error, state_name(State_dpg), Bit_idx_dpg);
    end

endmodule
