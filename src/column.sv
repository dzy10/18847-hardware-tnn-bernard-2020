/** 
 *  Assumes 1->0 transitions as events or spikes
 *  Values are encoded as spiketimes
 *  Weights are thermometer-coded. For e.g., 11111000 represnts a weight of 3, 11000000 represents 6 and so on
 *  Models an edge temporal (GRL) neuron with step-no-leak response function
 *
 *  @author Ranganath Selagamsetty (rselagam)
 */
`ifndef _COLUMN_SV_
`define _COLUMN_SV_

`include "internal_defines.vh"
`include "primitives.sv"
`include "receptive_field.sv"
`include "filter.sv"
`include "excitatory_column.sv"
`include "lateral_inhibition.sv"
`include "stdp.sv"

`timescale 1ns / 1ps

module column (rst_n, addr_clear, clk, mem_word, data_valid, addr, valid, winner, no_winner);
  // RF paramters
  parameter ADDR_BITS=`MEM_ADDR_BITS;
  parameter WORD_BITS=`MEM_WORD_BITS;
  parameter IMG_HEIGHT=`IMG_HEIGHT;
  parameter IMG_WIDTH=`IMG_WIDTH;
  parameter PIXEL_SIZE=`PIXEL_SIZE;
  parameter RF_HEIGHT=`RF_HEIGHT;
  parameter RF_WIDTH=`RF_WIDTH;
  parameter RF_CENTER_X=`RF_CENTER_X;
  parameter RF_CENTER_Y=`RF_CENTER_Y;

  parameter PERIOD=`TIME_PERIOD;

  // Filter parameters
  parameter PADDING_RADIUS=`FILTER_PADDING_RADIUS;

  // EC parameters
  parameter NEURONS=`NEURONS_PER_COLUMN;
  parameter SYNAPSES=1<<$clog2(2*RF_HEIGHT*RF_WIDTH);
  parameter NEURON_THRESHOLD = `NEURON_THRESHOLD;

  // STDP parameters
  parameter LFSR_BIT_WIDTH=16;
  parameter UCAPTURE=`STDP_MYU_CAPTURE;
  parameter UMINUS=`STDP_MYU_MINUS;
  parameter USEARCH=`STDP_MYU_SEARCH;
  parameter UBACKOFF=`STDP_MYU_BACKOFF;
  parameter UMIN=`STDP_MYU_MIN;

  input logic rst_n, addr_clear, clk;
  output logic valid;
  output logic [$clog2(NEURONS) - 1:0] winner;
  output logic no_winner;

  // Signals between mem controller and RF
  input logic  [WORD_BITS - 1:0] mem_word;
  input logic                    data_valid;
  output logic [ADDR_BITS - 1:0] addr;

  // Signals between RF and Filter
  logic rf_valid;
  logic [RF_HEIGHT - 1:0][RF_WIDTH -1:0][PIXEL_SIZE - 1:0] rf_buffer;
  logic filters_ready, on_ready, off_ready;

  // Signal for cycle counter
  logic [$clog2(PERIOD) - 1:0] timestep;
  logic en_counter_ON, en_counter_OFF, en_counter;

  // Signals for filters
  logic [RF_HEIGHT - 1:0][RF_WIDTH - 1:0] on_spikes, off_spikes;

  // Signals for excitatory column
  logic [NEURONS - 1:0][SYNAPSES - 1:0] neuron_in_spikes;
  logic [NEURONS - 1:0][SYNAPSES - 1:0][PERIOD - 1:0] neuron_in_weights;
  logic [NEURONS - 1:0] neuron_out_spikes;

  // Signals for lateral inhibition
  logic [NEURONS - 1:0] li_out_spikes;

  // State variables
  enum logic[1:0] {WAIT, RUN, DONE} state, next_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      state <= WAIT;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    case (state)
      WAIT: next_state = RUN;
      RUN:  next_state = (timestep == PERIOD - 1) ? DONE : RUN;
      DONE: next_state = WAIT;
      // default: next_state = state;
    endcase // state
  end

  always_comb begin
    case (state)
      WAIT: valid = 1'b0;
      RUN:  valid = (timestep == PERIOD - 1);
      DONE: valid = 1'b0;
      // default: valid = 1'bz;
    endcase // state
  end

  receptive_field #(.ADDR_BITS(ADDR_BITS),
                    .WORD_BITS(WORD_BITS),
                    .IMG_HEIGHT(IMG_HEIGHT),
                    .IMG_WIDTH(IMG_WIDTH),
                    .PIXEL_SIZE(PIXEL_SIZE),
                    .ROWS(RF_HEIGHT),
                    .COLS(RF_WIDTH),
                    .RF_CENTER_X(RF_CENTER_X),
                    .RF_CENTER_Y(RF_CENTER_Y)) 
  RF(               .rst_n, 
                    .addr_clear,
                    .clk,
                    .mem_word, 
                    .data_valid, 
                    .addr, 
                    .out_valid(rf_valid), 
                    .rf(rf_buffer), 
                    .filter_ready(filters_ready));

  assign en_counter = en_counter_ON & en_counter_OFF;
  counter #(        .WIDTH($clog2(PERIOD))) 
  cycle_count(      .rst_n, 
                    .clk, 
                    .clear(1'b0), 
                    .en(en_counter), 
                    .count(timestep));

  assign filters_ready = on_ready & off_ready;
  filter #(         .HEIGHT(RF_HEIGHT),
                    .WIDTH(RF_WIDTH),
                    .SIZE(PIXEL_SIZE),
                    .RADIUS(PADDING_RADIUS),
                    .T(ON)) 
  ON_FILTER (       .rst_n, 
                    .clk,
                    .in_valid(rf_valid), 
                    .in(rf_buffer), 
                    .spikes(on_spikes), 
                    .cycle(timestep),
                    .en_counter(en_counter_ON),
                    .ready(on_ready));

  filter #(         .HEIGHT(RF_HEIGHT),
                    .WIDTH(RF_WIDTH),
                    .SIZE(PIXEL_SIZE),
                    .RADIUS(PADDING_RADIUS),
                    .T(OFF)) 
  OFF_FILTER (      .rst_n,
                    .clk,
                    .in_valid(rf_valid), 
                    .in(rf_buffer), 
                    .spikes(off_spikes), 
                    .cycle(timestep),
                    .en_counter(en_counter_OFF),
                    .ready(off_ready));

  genvar i;
  generate
    for (i = 0; i < NEURONS; i++) begin
      assign neuron_in_spikes[i][$bits(on_spikes) - 1:0] = on_spikes;
      assign neuron_in_spikes[i][$bits({off_spikes, on_spikes}) - 1:$bits(on_spikes)] = off_spikes;
      if (SYNAPSES != $bits({on_spikes, off_spikes}))
        assign neuron_in_spikes[i][SYNAPSES - 1:$bits({on_spikes, off_spikes})] = '1;
    end 
  endgenerate
  excitatory_column #(.NEURONS(NEURONS), .SYNAPSES(SYNAPSES), .PERIOD(PERIOD), .THRESHOLD(NEURON_THRESHOLD))
  EC (.in_spikes(neuron_in_spikes), 
      .in_weights(neuron_in_weights), 
      .out_spikes(neuron_out_spikes));

  lateral_inhibition #(.NEURONS(NEURONS), .NUM_WINNERS(1)) 
  LI (.rst_n, .clk, .in_spikes(neuron_out_spikes), .out_spikes(li_out_spikes), .winner, .no_winner, .clear(timestep == 0 && en_counter));

  stdp #(           .NEURONS(NEURONS), 
                    .SYNAPSES(SYNAPSES),
                    .PERIOD(PERIOD),
                    .LFSR_BIT_WIDTH(LFSR_BIT_WIDTH),
                    .UCAPTURE(UCAPTURE),
                    .UMINUS(UMINUS),
                    .USEARCH(USEARCH),
                    .UBACKOFF(UBACKOFF),
                    .UMIN(UMIN))
  stdplasticity (   .rst_n, 
                    .clk, 
                    .input_spikes(neuron_in_spikes[0]), 
                    .output_spikes(li_out_spikes), 
                    .weights(neuron_in_weights), 
                    .cycle(timestep),
                    .en_counter(en_counter));

endmodule : column

`endif /* _COLUMN_SV_ */
