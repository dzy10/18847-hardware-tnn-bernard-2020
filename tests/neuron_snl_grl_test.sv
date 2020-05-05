// Author: Harideep Nair
// Assumes 1->0 transitions as events or spikes
// Values are encoded as spiketimes
//
// Testbench for step-no-leak neuron_grl

`timescale 1ns / 1ps

module neuron_snl_grl_test;

    reg [0:3] input_spikes;
    reg [0:3][7:0] input_weights;
    wire output_spike;

    neuron_snl_grl DUT (.output_spike(output_spike),
                           .input_spikes(input_spikes),
                           .input_weights(input_weights)
                           );

    initial
    begin

        $dumpfile("neuron_snl_grl.vcd");
        $dumpvars(0, neuron_snl_grl_test);

        input_spikes = '1;
        input_weights = '1;

        #5
        input_weights[0] = 8'b11111000;
        input_weights[1] = 8'b11100000;
        input_weights[2] = 8'b11110000;
        input_weights[3] = 8'b00000000;

        #15
        input_spikes[1] = 0;

        #4
        input_spikes[0] = 0;

        #6
        input_spikes[2] = 0;

        #2
        input_spikes[3] = 0;
        
        #10
        input_spikes = '1;

        #200
        $finish;

    end

endmodule
