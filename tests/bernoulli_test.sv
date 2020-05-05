`include "internal_defines.vh"
`include "bernoulli.sv"

`define NUM_ITERS 10000

module bernoulli_static_test;
    logic rst_n, clk;
    logic [0:3][6:0] threshold;
    logic [0:3] out;
    real ones [0:3];
    real percentage [0:3];

    assign threshold = {7'd32, 7'd64, 7'd96, 7'd127};

    //bernoulli_static #(.OUTPUTS(4), .U(64)) dut(.*);
    bernoulli_dynamic #(.OUTPUTS(4)) dut(.*);

    always_ff @(posedge clk or negedge rst_n) begin : proc_ones
      if(~rst_n) begin
        ones[0] <= 0;
        ones[1] <= 0;
        ones[2] <= 0;
        ones[3] <= 0;
      end else if (out) begin
        ones[0] <= ones[0] + out[0];
        ones[1] <= ones[1] + out[1];
        ones[2] <= ones[2] + out[2];
        ones[3] <= ones[3] + out[3];
      end else begin
        ones <= ones;
      end
    end

    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end

    initial begin
      $monitor($time);
      rst_n = 1;
      rst_n <= 0;

      $display($time,,"Expect ones to be half of total");
      @(posedge clk);
      rst_n <= 1;
      repeat(`NUM_ITERS) begin
        @(posedge clk);
      end

      for (int i = 0; i < 4; i++) begin
        percentage[i] = 100 * ones[i] / `NUM_ITERS;
        $display($time,,"Saw %d number of ones out of %d clocks ~ %f%% of the time", ones[i], `NUM_ITERS, percentage[i]);
      end

      #10 $finish;
    end

endmodule : bernoulli_static_test
