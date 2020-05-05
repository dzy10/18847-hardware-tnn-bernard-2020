/** 
 *  Assumes 1->0 transitions as events or spikes
 *  Values are encoded as spiketimes
 *  Weights are thermometer-coded. For e.g., 11111000 represnts a weight of 3, 11000000 represents 6 and so on
 *  Models an edge temporal (GRL) neuron with step-no-leak response function
 *
 *  @author Ranganath Selagamsetty (rselagam)
 */
`ifndef _PRIMITIVES_SV_
`define _PRIMITIVES_SV_

`include "internal_defines.vh"

`timescale 1ns / 1ps

module lte (rst_n, clk, a, b, c, clear);
  input logic rst_n, clk, a, b, clear;
  output logic c;

  logic b_old, c_old;

  always_ff @(posedge clk or negedge rst_n) begin : FF
    if(~rst_n) begin
      b_old <= 1;
      c_old <= 1;
    end else begin
      b_old <= b;
      c_old <= c;
    end
  end

  assign c = a | ((~b_old) & c_old & (~clear));
endmodule : lte

module counter (rst_n, clk, clear, en, count);
  parameter WIDTH=3;

  input logic  rst_n, clk, clear, en;
  output logic [WIDTH-1:0] count;

  always_ff @(posedge clk or negedge rst_n) begin : value
    if(~rst_n)
      count <= 0;
    else if (clear)
      count <= 0;
    else if (en)
      count <= count + 1'b1;
  end

endmodule

module register (rst_n, clk, clear, en, D, Q);
  parameter WIDTH=0;
  parameter RST_VAL=0;
  parameter CLEAR_VAL=0;

  input  logic               clk, en, rst_n, clear;
  input  logic [WIDTH-1:0]   D;
  output logic [WIDTH-1:0]   Q;

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n)
       Q <= RST_VAL;
    else if (clear)
       Q <= CLEAR_VAL;
    else if (en)
       Q <= D;
  end

endmodule : register

module mux (in, sel, out);
  parameter DATA_SIZE=8;
  parameter NUM_INPUTS=4;

  input logic [NUM_INPUTS - 1:0][DATA_SIZE - 1:0] in;
  input logic [$clog2(NUM_INPUTS) - 1:0] sel;
  output logic [DATA_SIZE - 1:0] out;
  
  assign out = in[sel];
endmodule

module adder (A, B, S, C);
  parameter DATA_SIZE=32;
  input logic  [DATA_SIZE - 1:0] A, B;
  output logic [DATA_SIZE - 1:0] S;
  output logic C;

  assign {C, S} = A + B;
endmodule

module var_adder_2D(in, out);
  parameter ROWS=2;
  parameter COLS=2;
  parameter IN_SIZE=8;
  parameter OUT_SIZE=32;
  input logic [ROWS - 1:0][COLS - 1:0][IN_SIZE - 1:0] in;
  output logic [OUT_SIZE - 1:0] out;

  logic [ROWS - 1:0][COLS - 1:0][OUT_SIZE - 1:0] inter_sums;
  genvar i, j;
  generate
    for (i = 0; i < ROWS; i++) begin
      for (j = 0; j < COLS; j++) begin
        if (i == 0 && j == 0) begin
          assign inter_sums[i][j] = in[i][j];
        end else if (i != 0 && j == 0) begin
          assign inter_sums[i][j] = inter_sums[i-1][COLS-1] + in[i][j];
        end else begin
          assign inter_sums[i][j] = inter_sums[i][j-1] + in[i][j];
        end
      end
    end
    assign out = inter_sums[ROWS - 1][COLS - 1];
  endgenerate
endmodule

module div(in, out);
  parameter IN_SIZE=32;
  parameter OUT_SIZE=8;
  parameter logic [IN_SIZE - 1:0] DIV=8;
  input logic [IN_SIZE - 1:0] in;
  output logic [OUT_SIZE - 1:0] out;
  logic [IN_SIZE - 1:0] quotient;
  assign quotient = in / DIV;
  assign out = quotient[OUT_SIZE - 1:0];
endmodule

module sat_sub(A, B, C);
  parameter SIZE=8;
  input logic [SIZE - 1:0] A, B;
  output logic [SIZE - 1:0] C;
  assign C = (A < B) ? '0 : (A - B);
endmodule
`endif /* _PRIMITIVES_SV_ */
