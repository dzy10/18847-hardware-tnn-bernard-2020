// Author: David Yang and Anja Kalaba
// Assumes 1->0 transitions as events or spikes
// Values are encoded as spiketimes
//
// Sorts the inputs in ascending order of arrival times

`ifndef _BITONIC_SORT_2_SV_
`define _BITONIC_SORT_2_SV_

`timescale 1ns / 1ps

module bitonic_sort_2 (sorted_out, raw_in); 
    input [0:1] raw_in;
    output [0:1] sorted_out;

    and min(sorted_out[0], raw_in[0], raw_in[1]);
    or  max(sorted_out[1], raw_in[0], raw_in[1]);
endmodule
`endif /* _BITONIC_SORT_2_SV_ */