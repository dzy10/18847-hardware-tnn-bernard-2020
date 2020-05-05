
module synth_top(
    input logic [3:0] input_spikes,
    input logic [3:0][7:0] input_weights,
    output logic output_spike
    );

    neuron_snl_grl_behavioral n(output_spike, input_spikes, input_weights);

endmodule
