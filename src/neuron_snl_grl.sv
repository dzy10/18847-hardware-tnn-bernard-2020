// Author: Harideep Nair
// Assumes 1->0 transitions as events or spikes
// Values are encoded as spiketimes
// Weights are thermometer-coded. For e.g., 11111000 represnts a weight of 3, 11000000 represents 6 and so on
// Models an edge temporal (GRL) neuron with step-no-leak response function

`ifndef _NEURON_SNL_GRL_SV_
`define _NEURON_SNL_GRL_SV_

`include "bitonic_sort_32.sv"

`timescale 1ns / 1ps

module neuron_snl_grl (output_spike, input_spikes, input_weights);
  parameter SYNAPSES = 4; // N - no. of input synapses
  parameter THRESHOLD = 11; // Theta - firing threshold of the neuron
  parameter RESP_FUN_PEAK = 8; // p - no. of up-steps/down-steps
  localparam SORT_SIZE = SYNAPSES*RESP_FUN_PEAK;
  genvar i, j;

  input [0:SYNAPSES - 1] input_spikes;
  input [0:SYNAPSES - 1][RESP_FUN_PEAK-1:0] input_weights;
  output output_spike;

  wire [0:SORT_SIZE - 1] up_times;
  wire [0:SORT_SIZE - 1] up_sort_out;
  
  // Up-step generation from input using weights
  generate
    for (i = 0; i < SYNAPSES; i = i + 1) begin: loop1
      for (j = 0; j < RESP_FUN_PEAK; j = j + 1) begin: loop2
        or g1 (up_times[i*RESP_FUN_PEAK+j], input_spikes[i], input_weights[i][j]);

      end
    end
  endgenerate

  // Sorter
  bitonic_sort_32 #(.N($clog2(SORT_SIZE))) up (
    .sorted_out(up_sort_out[0:SORT_SIZE - 1]), 
    .raw_in(up_times[0:SORT_SIZE - 1]));

  assign output_spike = up_sort_out[THRESHOLD-1];

endmodule

`endif /* _NEURON_SNL_GRL_SV_ */