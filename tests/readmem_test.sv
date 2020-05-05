
module readmem_test;

    logic [7:0] mem [$];

    initial begin
        $readmemh("../../tests/sample.mem", mem);
        for (int i = 0; i < 8; i++)
            $display("%h", mem[i]);

        $finish;
    end

endmodule : readmem_test
