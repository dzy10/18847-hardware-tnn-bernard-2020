`include "internal_defines.vh"
`include "stdp.sv"

`define NUM_NEURONS  2
`define NUM_SYNAPSES 2
`define NUM_ITERS    75

module up_counter (rst_n, clk, count);
  parameter SIZE=8;

  input logic  rst_n, clk;
  output logic [$clog2(SIZE) - 1:0] count;

  always_ff @(posedge clk or negedge rst_n) begin : value
    if(~rst_n) begin
      count <= 0;
    end else begin
      count <= count + 1'b1;
    end
  end

endmodule

module stdp_test;
    logic rst_n, clk;
    logic [`NUM_NEURONS - 1:0] output_spikes;
    logic [`NUM_NEURONS - 1:0][`NUM_SYNAPSES - 1:0] input_spikes;
    logic [$clog2(`TIME_PERIOD) - 1:0] cycle;
    logic [`NUM_NEURONS - 1:0][`NUM_SYNAPSES - 1:0][`TIME_PERIOD - 1:0] weights;

    up_counter #(.SIZE(`TIME_PERIOD)) cycle_count(.rst_n, .clk, .count(cycle));

    stdp #(.NEURONS(`NUM_NEURONS), .SYNAPSES(`NUM_SYNAPSES)) dut(.*);

    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end

    task send_branch1_spikes();
      assert(cycle == '0);
      @(posedge clk);
      input_spikes = '0;
      @(posedge clk);
      @(posedge clk);
      output_spikes = '0;
      @(posedge clk);
      @(posedge clk);
      @(posedge clk);
      @(posedge clk);
      @(posedge clk);
      input_spikes = '1;
      output_spikes = '1;
    endtask : send_branch1_spikes

    initial begin
        $monitor($time,,"cycle=%d input=%b output=%b, old_in=%b, old_out=%b, old_weights=%b", cycle, input_spikes, output_spikes, dut.old_in_spikes, dut.old_out_spikes, dut.old_weights);
        input_spikes = '1;
        output_spikes = '1;
        rst_n = 1;
        rst_n <= 0;

        $display($time,,"Can load spike registers?");
        @(posedge clk);
        rst_n <= 1;
        assert(cycle == '0);
        @(posedge clk);
        input_spikes = '0;
        @(posedge clk);
        @(posedge clk);
        output_spikes = '0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        input_spikes = '1;
        output_spikes = '1;
        @(posedge clk);

        repeat(`NUM_ITERS) begin
          send_branch1_spikes();
        end

        #10 $finish;
    end

endmodule : stdp_test
