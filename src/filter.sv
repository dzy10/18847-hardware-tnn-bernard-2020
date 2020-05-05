/** 
 * This module is the second stage in the spiking neural network column. The 
 * filter module is responsible for performing the same function as the retinal
 * ganglion in the neocortex. The filter module reads in pixel data from the 
 * receptive field module, processes the pixels by applying either a ON or OFF
 * filter, and finally generates a volley of spikes to the excitatory column.  
 *
 * Author: Anja Kalaba (akalaba)
 * Author: Sourav Panda (souravp)
 * Author: Ranganath Selagamsetty (rselagam)
 * Author: David Yang (dzy)
 * Last Updated: 5/5/2020
 */
`ifndef _FILTER_SV_
`define _FILTER_SV_

`timescale 1ns / 1ps
`include "internal_defines.vh"
`include "receptive_field.sv"

/**
 * This module is reponsible for applying either an ON or OFF filter to the 
 * pixel data read from the receptive field and generating a wave of spikes to 
 * the excitatory column.
 *
 * Inputs:
 *  - rst_n: Asynchronous reset signal (active low)
 *  - clk: Clock signal into the module
 *  - in_valid: Asserted when "in" holds valid data from the RF 
 *  - in: An array of pixel data from the RF
 *  - cycle: Which timestep we are in during the spike generation period
 * Outputs:
 *  - spikes: Volley of spikes fed to the excitatory column
 *  - en_counter: Asserted to enable the timestep counter
 *  - ready: Signal to the RF indiacting the filter is ready to consume new data
 */
module filter (rst_n, clk, in_valid, in, spikes, cycle, en_counter, ready);
  parameter HEIGHT=`RF_HEIGHT;
  parameter WIDTH=`RF_WIDTH;
  parameter SIZE=`PIXEL_SIZE;
  parameter RADIUS=`FILTER_PADDING_RADIUS;
  parameter filter_type T=ON;
  localparam PADDED_HEIGHT=HEIGHT+(2*RADIUS);
  localparam PADDED_WIDTH=WIDTH+(2*RADIUS);

  input logic  rst_n, clk, in_valid;
  input logic  [HEIGHT - 1:0][WIDTH - 1:0][SIZE - 1:0] in;
  input logic  [$clog2(`TIME_PERIOD) - 1:0] cycle;
  output logic [(HEIGHT * WIDTH) - 1:0] spikes;
  output logic en_counter, ready;

  logic filter_done, spike_gen_ready;
  
  logic [HEIGHT - 1:0][WIDTH - 1:0][SIZE - 1:0] filtered_out;
  logic [PADDED_HEIGHT - 1:0][PADDED_WIDTH - 1:0][SIZE - 1:0] padded_in;


  average     #(.ROWS(HEIGHT), 
                .COLS(WIDTH), 
                .SIZE(SIZE), 
                .RADIUS(RADIUS), 
                .T(T))
  filter_inst  (.rst_n,
                .clk, 
                .in(in), 
                .in_valid(in_valid),
                .filtered_out(filtered_out), 
                .filter_done(filter_done),
                .ready);

  fire        #(.HEIGHT(HEIGHT), 
                .WIDTH(WIDTH), 
                .SIZE(SIZE))
  spike_gen    (.rst_n, 
                .clk, 
                .filtered_out, 
                .cycle, 
                .in_valid(filter_done), 
                .spikes,
                .ready(spike_gen_ready),
                .en_counter);
endmodule : filter 

/**
 * This module is resposible for applying a filter to an array of pixels. The 
 * applied filter can be one of two types: ON and OFF. In both cases, for every 
 * pixel in the receptive field, all the neighboring pixels within a certain 
 * radius are accumulated, excluding the center pixel. This accumulation is 
 * then scaled down by the number of neighbors that were accumulated. If this 
 * filter is instantiated as an ON filter, the original pixel minus the scaled
 * accumulation of the neighbors is computed. If the filter is instantiated as
 * an OFF filter, the accumulation of neighbors minus the center pixel is 
 * computer. This array (with the same dimensions as the RF buffer array) is 
 * then fed to the next module in the filter, the spike generator.
 *
 * Inputs:
 *  - rst_n: Asynchronous reset signal (active low)
 *  - clk: Clock signal into the module
 *  - in_valid: Asserted when "in" holds valid data from the RF 
 *  - in: An array of pixel data from the RF
 * Outputs:
 *  - filtered_out: Filtered pixel array
 *  - filter_done: Asserted when the filter has finished working 
 *  - ready: Asserted if the averaging module can progress on new data
 */
module average (rst_n, clk, in, in_valid, filtered_out, filter_done, ready);
  parameter ROWS=`RF_HEIGHT;
  parameter COLS=`RF_WIDTH;
  parameter SIZE=`PIXEL_SIZE;
  parameter RADIUS=`FILTER_PADDING_RADIUS;
  parameter filter_type T=ON; 
  localparam PADDED_HEIGHT=ROWS+(2*RADIUS);
  localparam PADDED_WIDTH=COLS+(2*RADIUS);
  localparam NUM_PIXELS_AVERAGED=((1+2*RADIUS)*(1+2*RADIUS))-1;

  input logic  rst_n, clk;
  input logic  [ROWS - 1:0][COLS - 1:0][SIZE - 1:0] in;
  input logic  in_valid;
  output logic [ROWS - 1:0][COLS - 1:0][SIZE - 1:0] filtered_out;
  output logic filter_done, ready;

  logic [PADDED_HEIGHT - 1:0][PADDED_WIDTH - 1:0][SIZE - 1:0] averages;
  logic [ROWS - 1:0][COLS - 1:0][SIZE - 1:0] in_buffer;
  logic [PADDED_HEIGHT - 1:0][PADDED_WIDTH - 1:0][SIZE - 1:0] padded_in;
  logic en_acc_reg, en_div_reg, en_out_reg;

  genvar i, j;
  generate
    for (i = 0; i < PADDED_HEIGHT; i++) begin
      for (j = 0; j < PADDED_WIDTH; j++) begin
        if (i < RADIUS || i > (PADDED_HEIGHT - RADIUS - 1) ||
            j < RADIUS || j > (PADDED_WIDTH - RADIUS - 1))
          assign padded_in[i][j] = '0;
        else begin
          assign padded_in[i][j] = in_buffer[i - RADIUS][j - RADIUS];
        end
      end
    end
  endgenerate


  enum logic [1:0] {RESET, ACC, DIV, SUB} state, next_state;

  logic en_input_buffer;

  always_ff @(posedge clk or negedge rst_n) begin : proc_state
    if(~rst_n) begin
      state <= RESET;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    en_input_buffer = 1'b0;
    en_acc_reg = 1'b0;
    en_div_reg = 1'b0;
    en_out_reg = 1'b0;
    ready = 1'b0;
    case (state)
      RESET: begin
        if (in_valid) begin
          next_state = ACC;
          en_input_buffer = 1'b1;
          ready = 1'b1;
        end else begin
          next_state = RESET;
          ready = 1'b1;
        end
      end
      ACC: begin
        next_state = DIV;
        en_acc_reg = 1'b1; // current impl only takes one cyle to add
      end
      DIV: begin
        next_state = SUB;
        en_div_reg = 1'b1; // current impl only takes one cycle to div
      end
      SUB: begin
        next_state = RESET;
        en_out_reg = 1'b1; // current impl only takes one cycle to sub
      end
    endcase // state
  
  end

  register    #(.WIDTH(ROWS * COLS * SIZE))
  input_buffer (.rst_n,
                .clk,
                .clear(1'b0),
                .en(en_input_buffer),
                .D(in),
                .Q(in_buffer));

  logic [ROWS - 1:0][COLS - 1:0][31:0] sums;
  logic [ROWS - 1:0][COLS - 1:0][SIZE - 1:0] quotients; 
  genvar m, n;
  generate
    for (i = 0; i < ROWS; i++) begin
      for (j = 0; j < COLS; j++) begin
        logic [(2*RADIUS + 1) - 1:0][(2*RADIUS + 1) - 1:0][SIZE - 1:0]sub_array;
        logic [31:0] accumulation;
        logic [SIZE - 1:0] division;
        logic [SIZE - 1:0] difference;
        for (m = 0; m < (2*RADIUS + 1); m++) begin
          for (n = 0; n < (2*RADIUS + 1); n++) begin
            assign sub_array[m][n] = padded_in[i + m][j + n];
          end
        end
        var_adder_2D #(.ROWS(2*RADIUS + 1),
                   .COLS(2*RADIUS + 1),
                   .IN_SIZE(SIZE),
                   .OUT_SIZE(32))
        accumulator(.in(sub_array), .out(accumulation));

        register #(.WIDTH($bits(sums[i][j]))) 
        acc_reg   (.rst_n,
                   .clk, 
                   .clear(1'b0),
                   .en(en_acc_reg),
                   .D(accumulation - padded_in[i + RADIUS][j + RADIUS]),
                   .Q(sums[i][j]));

        div      #(.IN_SIZE($bits(sums[i][j])), 
                   .OUT_SIZE($bits(division)),
                   .DIV(NUM_PIXELS_AVERAGED))
        divider(   .in(sums[i][j]), 
                   .out(division));

        register #(.WIDTH($bits(quotients[i][j]))) 
        div_reg   (.rst_n,
                   .clk, 
                   .clear(1'b0),
                   .en(en_div_reg),
                   .D(division),
                   .Q(quotients[i][j]));

        if (T == ON) begin
         sat_sub #(.SIZE($bits(difference)))
         sub_on   (.A(padded_in[i + RADIUS][j + RADIUS]), 
                   .B(quotients[i][j]), 
                   .C(difference));
        end else if (T == OFF) begin
         sat_sub #(.SIZE($bits(difference)))
         sub_off  (.A(quotients[i][j]), 
                   .B(padded_in[i + RADIUS][j + RADIUS]), 
                   .C(difference));
        end
        register #(.WIDTH($bits(filtered_out[i][j]))) 
        out_reg   (.rst_n,
                   .clk, 
                   .clear(1'b0),
                   .en(en_out_reg),
                   .D(difference),
                   .Q(filtered_out[i][j]));
      end
    end
  endgenerate

  register #(.WIDTH(1))
  done_sig  (.rst_n,
             .clk,
             .clear(1'b0),
             .en(1'b1),
             .D(en_out_reg),
             .Q(filter_done));
endmodule

/**
 * This module is resposible for converting the array of pfiltered pixels into 
 * a volley of 1 to 0 spikes. Pixel values area converted to thermometer encoded
 * values that are fed to the excitatory column from MSB to LSB. A spike (1 to 
 * 0 transition) that occurs early (transition is in the more significant bits)
 * indicates a higher intensity filtered pixel value. 
 *
 * Inputs:
 *  - rst_n: Asynchronous reset signal (active low)
 *  - clk: Clock signal into the module
 *  - filtered_out: Filtered pixel array
 *  - cycle: Which timestep we are in during the spike generation period
 *  - in_valid: Asserted when "filtered_out" holds valid data from the RF 
 *  - in: An array of pixel data from the RF
 * Outputs:
 *  - spikes: Volley of spikes fed to the excitatory column
 *  - en_counter: Asserted to enable the timestep counter
 *  - ready: Asserted if the fire module can progress on new data
 */
module fire (rst_n, clk, filtered_out, cycle, in_valid, spikes, ready, 
                                                                   en_counter);
  parameter HEIGHT=`RF_HEIGHT;
  parameter WIDTH=`RF_WIDTH;
  parameter SIZE=`PIXEL_SIZE;
  localparam logic [SIZE - 1:0] MAX_PIXEL = '1;
  localparam DIV = MAX_PIXEL / `TIME_PERIOD;
  input logic  rst_n, clk;
  input logic  [HEIGHT - 1:0][WIDTH - 1:0][SIZE - 1:0] filtered_out;
  input logic  [$clog2(`TIME_PERIOD) - 1:0] cycle;
  input logic  in_valid;
  output logic [(HEIGHT * WIDTH) - 1:0] spikes;
  output logic ready, en_counter;

  logic [HEIGHT - 1:0][WIDTH - 1:0][`TIME_PERIOD - 1:0] thermometer_coded_img;
  logic load_buffer;

  enum logic [1:0] {WAIT, LOAD, READOUT} state, next_state;

  always_ff @(posedge clk or negedge rst_n) begin : proc_state
    if(~rst_n) begin
      state <= WAIT;
    end else begin
      state <= next_state;
    end
  end

  // Combinational translation from binary value to thermometer encoded value
  function logic[`TIME_PERIOD - 1:0] encode(input logic [SIZE - 1:0] in);
    return ~((1 << (in / DIV)) - 1'b1);
  endfunction

  genvar i, j;
  generate
    for (i = 0; i < HEIGHT; i++) begin : therm_row
      for (j = 0; j < WIDTH; j++) begin : therm_col
        // Input buffer to hold thermometer encoded values for filtered pixels
        register #(.WIDTH(`TIME_PERIOD))
        buffer    (.rst_n, 
                   .clk, 
                   .clear(1'b0),
                   .en(load_buffer),
                   .D(encode(filtered_out[i][j])),
                   .Q(thermometer_coded_img[i][j]));
      end
    end
  endgenerate

  // Convert filtered pixel array to array of thermometer encoded values
  generate
    for (i = 0; i < HEIGHT; i++) begin : set_output_row
      for (j = 0; j < WIDTH; j++) begin : set_output_col
        assign spikes[i * WIDTH + j] = (state == READOUT) ? 
          thermometer_coded_img[i][j][`TIME_PERIOD - cycle - 1] : 1'b1;
      end
    end 
  endgenerate


  // Three state mealy machine to generate spikes
  always_comb begin
    ready = 1'b0;
    en_counter = 1'b0;
    load_buffer = 1'b0;
    case (state)
      WAIT: begin
        ready = 1'b1;
        if (in_valid) begin
          next_state = LOAD;
        end else begin
          next_state = WAIT;
        end
      end
      LOAD: begin
        en_counter = 1'b1;
        load_buffer = 1'b1;
        next_state = READOUT;
      end
      READOUT: begin
        en_counter = 1'b1;
        if (cycle == `TIME_PERIOD - 1) begin
          if (in_valid) begin
            next_state = LOAD;
          end else begin
            next_state = WAIT;
          end
        end else begin
          next_state = READOUT;
        end
      end
    endcase
  end
endmodule
`endif /* _FILTER_SV_ */
