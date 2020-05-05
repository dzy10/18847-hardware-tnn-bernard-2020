/** 
 * This module implements a Winner-Take-All (WTA) approach toward lateral 
 * inhibition, allowing a single maximum to pass through. This module reads the 
 * output spikes fromt he excitatory column, and only allows the earliest output
 * spike to propagate.  
 *
 * Author: Anja Kalaba (akalaba)
 * Author: Sourav Panda (souravp)
 * Author: Ranganath Selagamsetty (rselagam)
 * Author: David Yang (dzy)
 * Last Updated: 5/5/2020
 */
`ifndef _LATERAL_INHIBITION_SV_
`define _LATERAL_INHIBITION_SV_

`include "internal_defines.vh"
`include "primitives.sv"

`timescale 1ns / 1ps

/**
 * This module is responsible for comparing the output of one neuron with the 
 * outputs from all the other neurons in the excitatory column. The LTE array 
 * instantiates a chain of LTE modules for every output. The resulting output
 * is a single bit line for each neuron output, where a spike is only 
 * transparent if happened at the same time or earlier than any other output.
 *
 * Inputs:
 *  - rst_n: Asynchronous reset signal (active low)
 *  - clk: Clock signal into the module
 *  - in_spikes: Volley of spikes fed from each neuron in the excitatory column
 *  - clear: Asserted when we are on the first timestep in a time period
 * Outputs:
 *  - inhibitied_spikes: Signal lines that have been LTE inhibited 
 */
module lte_array(rst_n, clk, in_spikes, inhibited_spikes, clear);
  parameter NUM_INPUTS=`NEURONS_PER_COLUMN;

  input logic rst_n, clk, clear;
  input logic [NUM_INPUTS - 1:0] in_spikes;
  output logic [NUM_INPUTS - 1:0] inhibited_spikes;

  genvar i, j;
  generate
    for (i = 0; i < NUM_INPUTS; i++) begin
      logic [NUM_INPUTS - 1:0] a_ltes, b_ltes, c_ltes;
      for (j = 0; j < NUM_INPUTS; j++) begin
        // input edge cases
        if (j == 0)
          assign a_ltes[j] = in_spikes[i];
        else
          assign a_ltes[j] = c_ltes[j-1];

        assign b_ltes[j] = in_spikes[j];

        // output edge cases
        if (i == j)
          assign c_ltes[j] = a_ltes[j]; 
        else
          lte inhibit(.rst_n, .clk, 
            .a(a_ltes[j]), .b(b_ltes[j]), .c(c_ltes[j]), .clear); 
      end
      assign inhibited_spikes[i] = c_ltes[NUM_INPUTS - 1];
    end 
  endgenerate
endmodule : lte_array

/**
 * This module instantiates an LTE array, and performs WTA inhibition. The WTA
 * logic prioritizes lower indexed neurons.
 *
 * Inputs:
 *  - rst_n: Asynchronous reset signal (active low)
 *  - clk: Clock signal into the module
 *  - in_spikes: Volley of spikes fed from each neuron in the excitatory column
 *  - clear: Asserted when we are on the first timestep in a time period
 * Outputs:
 *  - out_spikes: Signal lines that have been LTE and WTA inhibited 
 *  - winner: The ID of the neuron that had the earliest output spike
 *  - no_winner: Asserted if no output froom any neuron spiked
 */
module lateral_inhibition (rst_n, clk, in_spikes, out_spikes, winner, 
                                                              no_winner, clear);
  parameter NEURONS=`NEURONS_PER_COLUMN;
  parameter NUM_WINNERS=`NUM_WINNERS;

  input logic  rst_n, clk, clear;
  input logic  [NEURONS - 1:0] in_spikes;
  output logic [NEURONS - 1:0] out_spikes;
  output logic [$clog2(NEURONS) - 1:0] winner;
  output logic no_winner;

  logic [NEURONS - 1:0] inhibited_spikes;
  int loop;

  lte_array #(.NUM_INPUTS(NEURONS)) 
  array(      .rst_n,
              .clk,
              .in_spikes,
              .inhibited_spikes,
              .clear);

  // Perform tie breaking on winning spikes
  logic [NEURONS - 1:0] lower_index_zero_not_found;
  genvar i, j;
  generate
    for (i = 0; i < NEURONS; i++) begin
      if (i == 0)
        assign lower_index_zero_not_found[i] = 1'b1;
      else 
        assign lower_index_zero_not_found[i] = &inhibited_spikes[i - 1:0];
      always_comb begin
        case ({lower_index_zero_not_found[i], inhibited_spikes[i]})
          2'b11: out_spikes[i] = 1'b1;
          2'b10: out_spikes[i] = 1'b0;
          2'b01: out_spikes[i] = 1'b1;
          2'b00: out_spikes[i] = 1'b1;
          default: out_spikes[i] = 1'bz;
        endcase // {lower_index_zero_not_found[i], inhibited_spikes[i]}
      end
    end 
  endgenerate

  assign no_winner = &out_spikes;

  always_comb begin
    winner = 0;
    for (loop = 0; loop < NEURONS; loop++) begin
      if (out_spikes[loop] == 1'b0) begin
        winner = loop;
      end
    end
  end

endmodule : lateral_inhibition

`endif /* _LATERAL_INHIBITION_SV_ */
