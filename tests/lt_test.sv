`include "primitives.sv"

module lt_test;
    logic rst_n, clk, a, b, c;

    lt LT(.*);

    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end

    initial begin
        $monitor($time,,"a=%b b=%b c=%b c_old=%b", a, b, c, LT.c_old);
        rst_n = 1;
        rst_n <= 0;

        $display($time,,"a < b");
        @(posedge clk);
        rst_n <= 1;
        a <= 1; b <= 1;
        @(posedge clk);
        a <= 0; b <= 1;
        @(posedge clk);
        @(posedge clk);
        b <= 0;
        @(posedge clk);
        @(posedge clk);

        $display($time,,"a == b != inf");
        a <= 1; b <= 1;
        @(posedge clk);
        @(posedge clk);
        a <= 0; b <= 0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        $display($time,,"a > b");
        a <= 1; b <= 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        b <= 0;
        @(posedge clk);
        @(posedge clk);

        $display($time,,"a == b == inf");
        a <= 1; b <= 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        #10 $finish;
    end

endmodule : lt_test
