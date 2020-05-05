`include "internal_defines.vh"

module rf_test;
    logic rst_n, clk;
    logic [8-1:0] mem_word;
    logic [16-1:0] addr;
    logic valid;
    logic [5-1:0][5-1:0][8-1:0] rf;

    receptive_field #(.ADDR_BITS(16), .WORD_BITS(8), 
                      .IMG_HEIGHT(28), .IMG_WIDTH(28), .PIXEL_SIZE(8),
                      .RF_HEIGHT(5), .RF_WIDTH(5), .RF_CENTER_X(13),
                      .RF_CENTER_Y(13))
                    RF(.*);

    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end

    logic [8-1:0] mem [2*28*28:0];
    assign mem_word = mem[addr];

    initial begin
        $readmemh("../../tests/rf_test.mem", mem);
        rst_n = 0;
        rst_n <= 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge valid);
        $display("counting up");
        for (int i = 0; i < 5; i++) begin
            for (int j = 0; j < 5; j++)
                $write("%d ", rf[i][j]);
            $write("\n");
        end
        @(posedge valid);
        $display("\ncounting down");
        for (int i = 0; i < 5; i++) begin
            for (int j = 0; j < 5; j++)
                $write("%d ", rf[i][j]);
            $write("\n");
        end

        $finish;
    end

endmodule : rf_test
