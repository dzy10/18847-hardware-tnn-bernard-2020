
`ifndef _SWEEP_FILTER_SV_
`define _SWEEP_FILTER_SV_


`include "internal_defines.vh"
`include "filter.sv"

// `define SIZE      `IMG_WIDTH
// `define RADIUS    3

// module sweep_filter(in, cycle, spikes);

//   input logic  [$clog2(`TIME_PERIOD) - 1:0] cycle;
//   input logic  [`SIZE - 1:0][`SIZE - 1:0][`PIXEL_SIZE - 1:0] in;
//   output logic [(`SIZE * `SIZE) - 1:0] spikes;
//   // filter #(.T(ON), .HEIGHT(`SIZE), .WIDTH(`SIZE)) S(.*);

//   // filter #(.T(ON), .RADIUS(`RADIUS)) R(.*);

// endmodule

`endif /* _SWEEP_FILTER_SV_ */
