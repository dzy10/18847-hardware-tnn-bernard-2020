
module lfsr_test;

    logic rst_n, clk;
    logic [15:0] value;
    logic [65535:1] seen;

    lfsr LFSR(.*);

    initial begin
        clk = 1;
        forever #5 clk =  ~clk;
    end

    initial begin
        seen = 0;
        rst_n = 0;
        rst_n <= 1;
        for (int i = 0; i < 65535; i++) begin
            @(posedge clk);
            assert(!seen[value]);
            seen[value] <= 1;
        end
        @(posedge clk);
        assert(~seen == 0);
        $finish;
    end
endmodule : lfsr_test
