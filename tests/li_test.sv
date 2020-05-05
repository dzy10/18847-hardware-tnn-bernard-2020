`include "internal_defines.vh"
`include "lateral_inhibition.sv"

`define NUM_NEURONS 8

module li_test;
    logic rst_n, clk;
    logic [`NUM_NEURONS - 1:0] in_spikes;
    logic [`NUM_NEURONS - 1:0] out_spikes;

    lateral_inhibition #(.NEURONS(`NUM_NEURONS)) LI(.*);

    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end

    initial begin
        $monitor($time,,"in_spikes=%b inhibited_spikes=%b out_spikes=%b", in_spikes, LI.inhibited_spikes, out_spikes);
        in_spikes = '1;
        rst_n = 1;
        rst_n <= 0;

        $display($time,,"No winner");
        @(posedge clk);
        rst_n <= 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        assert(out_spikes == '1);

        $display($time,,"Clear Winner");
        @(posedge clk);
        in_spikes[0] <= 1'b0;
        @(posedge clk);
        in_spikes[2] <= 1'b0;
        in_spikes[3] <= 1'b0;
        @(posedge clk);
        in_spikes[1] <= 1'b0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        in_spikes[7] <= 1'b0;
        @(posedge clk);
        @(posedge clk);
        in_spikes[5] <= 1'b0;
        @(posedge clk);
        @(posedge clk);

        $display($time,,"Tie occurs");
        in_spikes <= '1;
        @(posedge clk);
        @(posedge clk);
        in_spikes[1] <= 1'b0;
        in_spikes[2] <= 1'b0;
        in_spikes[3] <= 1'b0;
        @(posedge clk);
        in_spikes[0] <= 1'b0;
        in_spikes[4] <= 1'b0;
        in_spikes[5] <= 1'b0;
        @(posedge clk);
        in_spikes[6] <= 1'b0;
        in_spikes[7] <= 1'b0;
        @(posedge clk);

        #10 $finish;
    end

endmodule : li_test
