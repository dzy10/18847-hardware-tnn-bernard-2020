/** 
 * This module is responsible for processing volleys of input spikes into 
 * their respective step-no-leak neurons. The outputs of these neurons drive the
 * direct outputs of this module.
 *
 * Author: Anja Kalaba (akalaba)
 * Author: Sourav Panda (souravp)
 * Author: Ranganath Selagamsetty (rselagam)
 * Author: David Yang (dzy)
 * Last Updated: 5/5/2020
 */
`ifndef _EXCITATORY_COLUMN_SV_
`define _EXCITATORY_COLUMN_SV_

`include "internal_defines.vh"
`include "neuron_snl_grl.sv"

`timescale 1ns / 1ps

/**
 * This module is responsible for processing volleys of input spikes into 
 * their respective step-no-leak neurons. The outputs of these neurons drive the
 * direct outputs of this module.
 *
 * Inputs:
 *  - in_spikes: Volley of spikes fed to each neuron in the excitatory column
 *  - in_weights: Spikes that represent thermometer encoded weights
 * Outputs:
 *  - out_spikes: The output spikes of the internal neurons
 */
module excitatory_column (in_spikes, in_weights, out_spikes);
  parameter NEURONS=`NEURONS_PER_COLUMN;
  // Need ON and OFF filter synapses, and sorter needs power of 2 synapses
  parameter SYNAPSES=1<<$clog2(2*`RF_HEIGHT*`RF_WIDTH);
  parameter PERIOD=`TIME_PERIOD;
  parameter THRESHOLD = `NEURON_THRESHOLD;

  input  [NEURONS - 1:0][SYNAPSES - 1:0] in_spikes;
  input  [NEURONS - 1:0][SYNAPSES - 1:0][PERIOD - 1:0] in_weights;
  output [NEURONS - 1:0] out_spikes;

  genvar i;
  generate
    for(i = 0; i < NEURONS; i++) begin : neurons 
      neuron_snl_grl #(.SYNAPSES(SYNAPSES), 
                       .RESP_FUN_PEAK(PERIOD),
                       .THRESHOLD(THRESHOLD)) 
      neuron(          .output_spike(out_spikes[i]), 
                       .input_spikes(in_spikes[i]), 
                       .input_weights(in_weights[i]));
    end
  endgenerate
endmodule : excitatory_column

`endif /* _EXCITATORY_COLUMN_SV_ */
