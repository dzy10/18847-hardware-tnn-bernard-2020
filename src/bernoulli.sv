/** 
 *  Assumes 1->0 transitions as events or spikes
 *  Values are encoded as spiketimes
 *  Weights are thermometer-coded. For e.g., 11111000 represnts a weight of 3, 11000000 represents 6 and so on
 *  Models an edge temporal (GRL) neuron with step-no-leak response function
 *
 *  LCG parameters from glibc implementation, retrieved from
 *  https://sourceware.org/git/?p=glibc.git;a=blob;f=stdlib/random_r.c;hb=glibc-2.26#l362
 *
 *  @author Ranganath Selagamsetty (rselagam)
 */
`ifndef _BERNOULLI_SV_
`define _BERNOULLI_SV_

`timescale 1ns / 1ps
`include "internal_defines.vh"
`include "lfsr.sv"

module bernoulli_static (rst_n, clk, out);
  parameter WIDTH=16;
  parameter CMP_WIDTH=7;
  parameter OUTPUTS=8;
  parameter SEED='hdead;
  parameter U='d32;

  input logic  rst_n, clk;
  output logic [OUTPUTS - 1:0] out;

  logic [WIDTH - 1:0] lfsr_val;
  logic [OUTPUTS - 1:0][CMP_WIDTH - 1:0] cmp_vals;
  logic [30:0] indices [OUTPUTS * CMP_WIDTH - 1:0];

  lfsr #(.WIDTH(WIDTH), .SEED(SEED)) rng(.rst_n, .clk, .value(lfsr_val));

  genvar i, j;
  generate
    assign indices[0] = SEED;
    for (i = 1; i < OUTPUTS * CMP_WIDTH; i++) begin
      `ifdef SIM
      assign indices[i] = indices[i - 1] * 31'd1103515245 + 31'd12345;
      `else
      assign indices[i] = lfsr_val[i % WIDTH];
      `endif
    end
    for (i = 0; i < OUTPUTS; i++) begin
      for (j = 0; j < CMP_WIDTH; j++) begin
        assign cmp_vals[i][j] = lfsr_val[indices[i * CMP_WIDTH + j] % WIDTH];
      end
      assign out[i] = (cmp_vals[i] < U);
    end
  endgenerate
endmodule : bernoulli_static

module bernoulli_dynamic (rst_n, clk, threshold, out);
  parameter WIDTH=16;
  parameter CMP_WIDTH=7;
  parameter OUTPUTS=8;
  parameter SEED='hdead;

  input logic  rst_n, clk;
  input logic [OUTPUTS - 1:0][CMP_WIDTH - 1:0] threshold;
  output logic [OUTPUTS - 1:0] out;

  logic [WIDTH - 1:0] lfsr_val;
  logic [OUTPUTS - 1:0][CMP_WIDTH - 1:0] cmp_vals;
  logic [30:0] indices [OUTPUTS * CMP_WIDTH - 1:0];

  lfsr #(.WIDTH(WIDTH), .SEED(SEED)) rng(.rst_n, .clk, .value(lfsr_val));

  genvar i, j;
  generate
    assign indices[0] = SEED;
    for (i = 1; i < OUTPUTS * CMP_WIDTH; i++) begin
      `ifdef SIM
      assign indices[i] = indices[i - 1] * 31'd1103515245 + 31'd12345;
      `else
      assign indices[i] = lfsr_val[i % WIDTH];
      `endif
    end
    for (i = 0; i < OUTPUTS; i++) begin
      for (j = 0; j < CMP_WIDTH; j++) begin
        assign cmp_vals[i][j] = lfsr_val[indices[i * CMP_WIDTH + j] % WIDTH];
      end
      assign out[i] = (cmp_vals[i] < threshold[i]);
    end
  endgenerate
endmodule : bernoulli_dynamic

`endif /* _BERNOULLI_SV_ */
