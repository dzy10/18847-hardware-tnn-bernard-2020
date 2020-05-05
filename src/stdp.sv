/** 
 * This module implements the synaptic weight learning rules as discussed in 
 * lecture. 
 *
 * Author: Anja Kalaba (akalaba)
 * Author: Sourav Panda (souravp)
 * Author: Ranganath Selagamsetty (rselagam)
 * Author: David Yang (dzy)
 * Last Updated: 5/5/2020
 */
`ifndef _STDP_SV_
`define _STDP_SV_

`timescale 1ns / 1ps
`include "internal_defines.vh"
`include "bernoulli.sv"
`include "primitives.sv"

/**
 * This module stores the thermometer encoded weights for every synapses on 
 * every neuron.
 *
 * Inputs:
 *  - rst_n: Asynchronous reset signal (active low)
 *  - clk: Clock signal into the module
 *  - in_spikes: Volley of spikes fed to each neuron in the excitatory column
 *  - out_spikes: Volley of spikes out of the lateral inhibition module
 *  - weights: The newly updates weights
 * Outputs:
 *  - old_in_spikes: The old thermometer encoded input spikes
 *  - old_out_spikes: The old thermometer encoded output spikes
 *  - old_weights: The old thermometer encoded weights for all the synapses
 */
module weight_memory (rst_n, clk, in_spikes, out_spikes, weights, 
                                    old_in_spikes, old_out_spikes, old_weights);
  parameter NEURONS=`NEURONS_PER_COLUMN;
  parameter SYNAPSES=`RF_HEIGHT*`RF_WIDTH;
  parameter PERIOD=`TIME_PERIOD;

  input logic  rst_n, clk;
  input logic  [SYNAPSES - 1:0][PERIOD - 1:0] in_spikes;
  input logic  [NEURONS - 1:0][PERIOD - 1:0]  out_spikes;
  input logic  [NEURONS - 1:0][SYNAPSES - 1:0][PERIOD - 1:0] weights;

  output logic [SYNAPSES - 1:0][PERIOD - 1:0] old_in_spikes; 
  output logic [NEURONS - 1:0][PERIOD - 1:0] old_out_spikes;
  output logic [NEURONS - 1:0][SYNAPSES - 1:0][PERIOD - 1:0] old_weights;

  logic [NEURONS - 1:0][SYNAPSES - 1:0][PERIOD - 1:0] initial_weights;
  genvar i, j;
  generate
    for (i = 0; i < NEURONS; i++) begin
      for (j = 0; j < SYNAPSES; j++) begin
        assign initial_weights[i][j] = 8'hf0;
      end
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin : weights_FF
    if(~rst_n) begin
      old_in_spikes <= '1;
      old_out_spikes <= '1;
      old_weights <= initial_weights;
    end else begin
      old_in_spikes <= in_spikes;
      old_out_spikes <= out_spikes;
      old_weights <= weights;
    end
  end
endmodule

/**
 * The lookup table for the positive stabilization function
 *
 * Inputs:
 *  - old_weights: The old thermometer encoded weights
 * Outputs:
 *  - thresholds: What threshold value to pass to a bernoulli dynamic 
 */
module f_pos_lut (old_weights, thresholds);
  parameter NEURONS=`NEURONS_PER_COLUMN;
  parameter SYNAPSES=`RF_HEIGHT*`RF_WIDTH;
  parameter PERIOD=`TIME_PERIOD;
  parameter CMP_WIDTH=`STDP_MYU_WIDTH;

  input logic [NEURONS - 1:0][SYNAPSES - 1:0][PERIOD - 1:0] old_weights;
  output logic [NEURONS - 1:0][SYNAPSES - 1:0][CMP_WIDTH - 1:0] thresholds;

  function logic [CMP_WIDTH - 1:0] calc_myu_F_plus(input logic [PERIOD - 1:0] w);
    case(w)
      8'hFF: return 7'h00;
      8'hFE: return 7'h1E;
      8'hFC: return 7'h38;
      8'hF8: return 7'h4E;
      8'hF0: return 7'h60;
      8'hE0: return 7'h6E;
      8'hC0: return 7'h78;
      8'h80: return 7'h7E;
      8'h00: return 7'h7F;
      default: return 7'hzz; // error case, should never reach here
    endcase // w
  endfunction : calc_myu_F_plus

  genvar i, j;
  generate
    for (i = 0; i < NEURONS; i++) begin
      for (j = 0; j < SYNAPSES; j++) begin
        assign thresholds[i][j] = calc_myu_F_plus(old_weights[i][j]);
      end
    end
  endgenerate
endmodule  

/**
 * The lookup table for the negative stabilization function
 *
 * Inputs:
 *  - old_weights: The old thermometer encoded weights
 * Outputs:
 *  - thresholds: What threshold value to pass to a bernoulli dynamic 
 */
module f_neg_lut (old_weights, thresholds);
  parameter NEURONS=`NEURONS_PER_COLUMN;
  parameter SYNAPSES=`RF_HEIGHT*`RF_WIDTH;
  parameter PERIOD=`TIME_PERIOD;
  parameter CMP_WIDTH=`STDP_MYU_WIDTH;

  input logic [NEURONS - 1:0][SYNAPSES - 1:0][PERIOD - 1:0] old_weights;
  output logic [NEURONS - 1:0][SYNAPSES - 1:0][CMP_WIDTH - 1:0] thresholds;

  function logic [CMP_WIDTH - 1:0] calc_myu_F_minus(input logic [PERIOD - 1:0] w);
    case(w)
      8'hFF: return 7'h7F;
      8'hFE: return 7'h7E;
      8'hFC: return 7'h78;
      8'hF8: return 7'h6E;
      8'hF0: return 7'h60;
      8'hE0: return 7'h4E;
      8'hC0: return 7'h38;
      8'h80: return 7'h1E;
      8'h00: return 7'h00;
      default: return 7'hzz; // error case, should never reach here
    endcase // w
  endfunction : calc_myu_F_minus
  
  genvar i, j;
  generate
    for (i = 0; i < NEURONS; i++) begin
      for (j = 0; j < SYNAPSES; j++) begin
        assign thresholds[i][j] = calc_myu_F_minus(old_weights[i][j]);
      end 
    end 
  endgenerate
endmodule  

/**
 * The hardware for Bernoulli random variables, to perform weight updates in the
 * stdp module.
 *
 * Inputs:
 *  - rst_n: Asynchronous reset signal (active low)
 *  - clk: Clock signal into the module
 *  - thresh_sel: Which myu value to use as the threshold
 *  - pos_threshold: Threshold for the positive stabilization function
 *  - neg_threshold: Threshold for the negative stabilization function
 * Outputs:
 *  - b_branch: BRV with value 0 or 1 bases on branch
 *  - b_min: BRV for the B min computation
 *  - f_minus: BRV for the negative stabilization function
 *  - f_plus: BRV for the positive stabilization function
 */
module bernoullis (rst_n, clk, thresh_sel, pos_thresholds, neg_thresholds, b_branch, b_min, f_minus, f_plus);
  parameter NEURONS=`NEURONS_PER_COLUMN;
  parameter SYNAPSES=`RF_HEIGHT*`RF_WIDTH;
  parameter PERIOD=`TIME_PERIOD;
  parameter LFSR_BIT_WIDTH=16;
  parameter CMP_WIDTH=`STDP_MYU_WIDTH;
  parameter logic [CMP_WIDTH - 1:0] UCAPTURE=`STDP_MYU_CAPTURE;
  parameter logic [CMP_WIDTH - 1:0] UMINUS=`STDP_MYU_MINUS;
  parameter logic [CMP_WIDTH - 1:0] USEARCH=`STDP_MYU_SEARCH;
  parameter logic [CMP_WIDTH - 1:0] UBACKOFF=`STDP_MYU_BACKOFF;
  parameter UMIN=`STDP_MYU_MIN;

  input logic  rst_n, clk;
  input logic  [NEURONS - 1:0][SYNAPSES - 1:0][1:0] thresh_sel;
  input logic  [NEURONS - 1:0][SYNAPSES - 1:0][CMP_WIDTH - 1:0] pos_thresholds, neg_thresholds;
  output logic [NEURONS - 1:0][SYNAPSES - 1:0] b_branch, b_min, f_plus, f_minus;

  logic [NEURONS - 1:0][SYNAPSES - 1:0][CMP_WIDTH - 1:0] branch_threshold;

  genvar i, j;
  generate
    for (i = 0; i < NEURONS; i++) begin
      // Generate bernoulli random variables
      bernoulli_static #(.WIDTH(LFSR_BIT_WIDTH), .SEED((i + 16'hdead) * (i + 1)), .CMP_WIDTH(CMP_WIDTH), .OUTPUTS(SYNAPSES), .U(UMIN)) B_min(
        .rst_n, .clk, .out(b_min[i]));

      bernoulli_dynamic #(.WIDTH(LFSR_BIT_WIDTH), .SEED((i + 16'hfeed) * (i + 2)), .CMP_WIDTH(CMP_WIDTH), .OUTPUTS(SYNAPSES)) B_branch(
        .rst_n,
        .clk,
        .threshold(branch_threshold[i]),
        .out(b_branch[i]));

      // Generate stabilization factors using lookup tables
      bernoulli_dynamic #(.WIDTH(LFSR_BIT_WIDTH), .SEED((i + 16'hacab) * (i + 3)), .CMP_WIDTH(CMP_WIDTH), .OUTPUTS(SYNAPSES)) f_pos (
        .rst_n,
        .clk, 
        .threshold(pos_thresholds[i]),
        .out(f_plus[i]));

      bernoulli_dynamic #(.WIDTH(LFSR_BIT_WIDTH), .SEED((i + 16'hcafe) * (i + 4)), .CMP_WIDTH(CMP_WIDTH), .OUTPUTS(SYNAPSES)) f_neg (
        .rst_n,
        .clk, 
        .threshold(neg_thresholds[i]),
        .out(f_minus[i]));

      for (j = 0; j < SYNAPSES; j++) begin  
        mux #(.DATA_SIZE(CMP_WIDTH), .NUM_INPUTS(4)) sel_threshold(
          .in({UCAPTURE, UMINUS, USEARCH, UBACKOFF}),
          .sel(thresh_sel[i][j]),
          .out(branch_threshold[i][j]));
      end

    end 
  endgenerate
endmodule

/**
 * The hardware for Bernoulli random variables, to perform weight updates in the
 * stdp module.
 *
 * Inputs:
 *  - rst_n: Asynchronous reset signal (active low)
 *  - clk: Clock signal into the module
 *  - input_spikes: Volley of spikes fed to each neuron in the excitatory column
 *  - output_spikes: Volley of spikes out of the lateral inhibition module
 *  - cycle: Which timestep we are in the current time period
 *  - en_counter: Asserted when in and out spikes are valid
 * Outputs:
 *  - weights: The updates weights
 */
module stdp (rst_n, clk, input_spikes, output_spikes, weights, cycle, en_counter);
  parameter NEURONS=`NEURONS_PER_COLUMN;
  parameter SYNAPSES=`RF_HEIGHT*`RF_WIDTH*2;
  parameter PERIOD=`TIME_PERIOD;
  parameter LFSR_BIT_WIDTH=16;
  parameter logic [LFSR_BIT_WIDTH - 1:0] UCAPTURE=`STDP_MYU_CAPTURE;
  parameter logic [LFSR_BIT_WIDTH - 1:0] UMINUS=`STDP_MYU_MINUS;
  parameter logic [LFSR_BIT_WIDTH - 1:0] USEARCH=`STDP_MYU_SEARCH;
  parameter logic [LFSR_BIT_WIDTH - 1:0] UBACKOFF=`STDP_MYU_BACKOFF;
  parameter UMIN=`STDP_MYU_MIN;
  parameter CMP_WIDTH=`STDP_MYU_WIDTH;

  input logic  rst_n, clk;
  input logic  [NEURONS - 1:0] output_spikes;
  input logic  [$clog2(PERIOD) - 1:0] cycle;
  input logic  [SYNAPSES - 1:0] input_spikes;
  input logic  en_counter;
  output logic [NEURONS - 1:0][SYNAPSES - 1:0][PERIOD - 1:0] weights;

  logic [NEURONS - 1:0][PERIOD - 1:0] old_out_spikes, out_spikes;
  logic [SYNAPSES - 1:0][PERIOD - 1:0] old_in_spikes, in_spikes;
  logic [NEURONS - 1:0][SYNAPSES - 1:0][PERIOD - 1:0] old_weights;
  logic [NEURONS - 1:0][SYNAPSES - 1:0] b_min;
  logic [NEURONS - 1:0][SYNAPSES - 1:0] f_plus, f_minus, max_f_pos_b_min, max_f_neg_b_min;
  logic [NEURONS - 1:0][SYNAPSES - 1:0] branch1, branch2, branch3, branch4;

  logic [NEURONS - 1:0][SYNAPSES - 1:0] b_branch;
  logic [NEURONS - 1:0][SYNAPSES - 1:0][1:0] thresh_sel;
  logic [NEURONS - 1:0][SYNAPSES - 1:0][CMP_WIDTH - 1:0] branch_threshold;

  weight_memory #(.NEURONS(NEURONS), 
                  .SYNAPSES(SYNAPSES), 
                  .PERIOD(PERIOD))
  spike_mem (     .rst_n, 
                  .clk, 
                  .in_spikes, 
                  .out_spikes, 
                  .weights, 
                  .old_in_spikes, 
                  .old_out_spikes, 
                  .old_weights);

  logic [NEURONS - 1:0][SYNAPSES - 1:0][CMP_WIDTH - 1:0] pos_thresholds, neg_thresholds;

  f_pos_lut #(    .NEURONS(NEURONS), 
                  .SYNAPSES(SYNAPSES), 
                  .PERIOD(PERIOD), 
                  .CMP_WIDTH(CMP_WIDTH))
  pos_lut (       .old_weights, 
                  .thresholds(pos_thresholds));

  f_neg_lut #(    .NEURONS(NEURONS), 
                  .SYNAPSES(SYNAPSES), 
                  .PERIOD(PERIOD), 
                  .CMP_WIDTH(CMP_WIDTH))
  neg_lut (       .old_weights, 
                  .thresholds(neg_thresholds));

  bernoullis #(   .NEURONS(NEURONS), 
                  .SYNAPSES(SYNAPSES), 
                  .PERIOD(PERIOD), 
                  .LFSR_BIT_WIDTH(LFSR_BIT_WIDTH),
                  .UCAPTURE(UCAPTURE), 
                  .UMINUS(UMINUS), 
                  .USEARCH(USEARCH), 
                  .UBACKOFF(UBACKOFF), 
                  .UMIN(UMIN))
  random_vars (   .rst_n, 
                  .clk, 
                  .thresh_sel, 
                  .pos_thresholds, 
                  .neg_thresholds, 
                  .b_branch, 
                  .b_min, 
                  .f_minus, 
                  .f_plus);

  genvar i, j;
  generate
    // Capture info about input and output spikes
    for (i = 0; i < NEURONS; i++) begin : neurons_loop
      for (j = 0; j < PERIOD; j++) begin : output_timestep_loop
        assign out_spikes[i][j] = (cycle == (PERIOD - j - 1)) ? output_spikes[i] : old_out_spikes[i][j];
      end
    end
    for (i = 0; i < SYNAPSES; i++) begin : synapses_loop
      for (j = 0; j < PERIOD; j++) begin : input_timestep_loop
        assign in_spikes[i][j] = (cycle == (PERIOD - j - 1)) ? input_spikes[i] : old_in_spikes[i][j];
      end
    end 

    
    for (i = 0; i < NEURONS; i++) begin : bernoulli_neuron_loop
      for (j = 0; j < SYNAPSES; j++) begin : bernoulli_synapse_loop
        assign max_f_pos_b_min[i][j] = f_plus[i][j] | b_min[i][j];
        assign max_f_neg_b_min[i][j] = f_minus[i][j] | b_min[i][j];

        assign branch1[i][j] = b_branch[i][j] & max_f_pos_b_min[i][j];
        assign branch2[i][j] = b_branch[i][j] & max_f_neg_b_min[i][j];
        assign branch3[i][j] = b_branch[i][j] & max_f_pos_b_min[i][j];
        assign branch4[i][j] = b_branch[i][j] & max_f_neg_b_min[i][j];

        // STDP rules
        always_comb begin
          thresh_sel[i][j] = 2'd0;
          if (!en_counter && cycle == 0) begin

            if (old_in_spikes[j] != 8'hff && old_out_spikes[i] != 8'hff && 
                 ($unsigned(old_in_spikes[j]) <= $unsigned(old_out_spikes[i]))) begin
              weights[i][j] = $signed(old_weights[i][j]) << branch1[i][j];
              thresh_sel[i][j] = 2'd3;
            end else if (old_in_spikes[j] != 8'hff && old_out_spikes[i] != 8'hff && 
                 ($unsigned(old_in_spikes[j]) > $unsigned(old_out_spikes[i]))) begin
              thresh_sel[i][j] = 2'd2;
              if (branch2[i][j])
                weights[i][j] = {1'b1, old_weights[i][j][PERIOD - 1:1]};
              else
                weights[i][j] = old_weights[i][j];
            end else if (old_in_spikes[j] != 8'hff && old_out_spikes[i] == 8'hff) begin
              thresh_sel[i][j] = 2'd1;
              weights[i][j] = $signed(old_weights[i][j]) << branch3[i][j];
            end else if (old_in_spikes[j] == 8'hff && old_out_spikes[i] != 8'hff) begin
              thresh_sel[i][j] = 2'd0;
              if (branch4[i][j])
                weights[i][j] = {1'b1, old_weights[i][j][PERIOD - 1:1]};
              else
                weights[i][j] = old_weights[i][j];
            end else begin
              weights[i][j] = old_weights[i][j];
            end
          end else begin
            weights[i][j] = old_weights[i][j];
          end  
        end
      end
    end
  endgenerate

endmodule : stdp

`endif /* _STDP_SV_ */
