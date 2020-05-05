//x^16 + x^9 + x^8 + x^7 + x^6 + x^4 + x^3 + x^2 + 1

`ifndef _LFSR_SV
`define _LFSR_SV

module lfsr(rst_n, clk, value);
    parameter WIDTH=16;
    parameter SEED='hdead;
    input  logic rst_n, clk;
    output logic [WIDTH - 1:0] value;

    logic [WIDTH - 1:0] next, polynomial;

    always_ff @(posedge clk, negedge rst_n) begin
        if (~rst_n)
            value <= SEED;
        else
            value <= next;
    end

    always_comb begin
        case(WIDTH)
            16: polynomial = 16'h01ee;
        endcase
        /* this synthesizes the same as a bunch of individual assignments
         * of the form next[p-1] = value[p] ^ value[0] */
        next = {value[0], value[15:1]} ^ ({16{value[0]}} & polynomial);
    end

endmodule : lfsr

`endif /* _LFSR_SV */
