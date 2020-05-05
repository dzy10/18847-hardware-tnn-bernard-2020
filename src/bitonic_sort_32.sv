// Author: David Yang and Anja Kalaba
// Assumes 1->0 transitions as events or spikes
// Values are encoded as spiketimes
//
// Sorts the inputs in ascending order of arrival times

`ifndef _BITONIC_SORT_32_SV_
`define _BITONIC_SORT_32_SV_

`include "bitonic_sort_2.sv"

`timescale 1ns / 1ps

module bitonic_sort_32 (sorted_out, raw_in); 

    parameter N = 5;
    parameter INPUT_SIZE = 1<<N;
    localparam HALF_INPUT_SIZE = 1<<(N-1);
    genvar i, j, k;

    input [0:INPUT_SIZE-1] raw_in;
    output [0:INPUT_SIZE-1] sorted_out;

    /* Declare any intermediate wires you use */
    logic [0:HALF_INPUT_SIZE-1] top_in, top_out, 
                                bottom_in, bottom_out, reversed_bottom_out;
    assign top_in = raw_in[0:HALF_INPUT_SIZE-1];
    assign bottom_in = raw_in[HALF_INPUT_SIZE:INPUT_SIZE-1];
    
    /* Instantiate two 16-input sorters here  */
    generate
        if (N<=0) begin
            assign sorted_out = raw_in;
        end else if (N==1) begin
            bitonic_sort_2 sort2(sorted_out, raw_in);
            assign top_out = '0;
            assign bottom_out = '0;
        end else begin
            bitonic_sort_32 #(.N(N-1)) top(top_out, top_in),
                                       bottom(bottom_out, bottom_in);
        end
    endgenerate

    /* WRITE YOUR CODE FOR THE LAST STAGE */
    logic [0:N][0:INPUT_SIZE-1] level_out;
    assign reversed_bottom_out = {<<{bottom_out}};
    assign level_out[0] = {top_out, reversed_bottom_out};
    generate
        if (N>1) begin
            // final stage has N levels
            for (i=0; i<N; i++) begin : level
                // each level has 2^i groups of lines
                for (j=0; j<(1<<i); j++) begin : group
                    // within each group, lines are sorted in pairs,
                    // with one line from each half of the group
                    for (k=0; k<INPUT_SIZE/(1<<i)/2; k++) begin : lines
                        logic [0:1] sort2_in;
                        logic [0:1] sort2_out;

                        assign sort2_in = {level_out[i][j*INPUT_SIZE/(1<<i)+k],
                                           level_out[i][j*INPUT_SIZE/(1<<i)+k
                                                +INPUT_SIZE/(1<<i)/2]};
                        assign {level_out[i+1][j*INPUT_SIZE/(1<<i)+k],
                                level_out[i+1][j*INPUT_SIZE/(1<<i)+k
                                    +INPUT_SIZE/(1<<i)/2]} = sort2_out;

                        bitonic_sort_2 sort2(sort2_out, sort2_in);
                    end
                end
            end
            assign sorted_out = level_out[N];
        end
    endgenerate

endmodule

`endif /* _BITONIC_SORT_32_SV_ */