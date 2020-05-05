/** 
 * This module is the first stage in the spiking neural network column. The 
 * receptive is responsible for interacting with a memory controller unit. This 
 * module cycles through the addresses to fetch image data pixels from memory.
 * Once all the pixels located within the receptive field are fetched, the 
 * receptive field buffer output is presented and out_valid is asserted excatly 
 * one cycle before the rf is valid.  
 *
 * Author: Anja Kalaba (akalaba)
 * Author: Sourav Panda (souravp)
 * Author: Ranganath Selagamsetty (rselagam)
 * Author: David Yang (dzy)
 * Last Updated: 5/5/2020
 */
`ifndef _RECEPTIVE_FIELD_SV_
`define _RECEPTIVE_FIELD_SV_

`timescale 1ns / 1ps
`include "internal_defines.vh"

/**
 * This module interacts with the memory controller unit and the filter. Using 
 * finite state machine and certain control signals, this module performs 
 * handshaking with the MCU and the downstream filters. This module provides the
 * memory controller pixel addresses, and the memory controller provides the 
 * pixel data at those addresses. Additionally, is is the role of the memory 
 * controller to asser the data_valid signal when the memory controller has 
 * successfully serviced the request.
 *
 * This module then provides the downstream filters access to the buffered pixel
 * data for the receptive field. If the downstream filters are not ready to 
 * process these pixels, this module waits, continually asserting out_valid.
 * Once filter_ready is asserted, this module feeds the buffered pixels to the 
 * filters, and begins reading the next image on the next clock cycle. 
 *
 * Inputs:
 *  - rst_n: Asynchronous reset signal (active low)
 *  - clk: Clock signal into the module
 *  - addr_clear: Resets the address register to init value (active high)
 *  - mem_word: The data the memory controller unit has fetched
 *  - data_valid: Asserted if mem_word contains valid data from memory
 *  - filter_ready: Signal indicating filter is ready to consume rf data 
 * Outputs:
 *  - addr: What address the memory controller unit should read from next
 *  - rf: The output buffer that holds the pixels of the receptive field
 *  - out_valid: Asserted on the smae cycle that the rf holds valid data
 */
module receptive_field (rst_n, addr_clear, clk, mem_word, data_valid, 
                                            addr, out_valid, rf, filter_ready);
  parameter ADDR_BITS=`MEM_ADDR_BITS;
  parameter WORD_BITS=`MEM_WORD_BITS;
  parameter IMG_HEIGHT=`IMG_HEIGHT;
  parameter IMG_WIDTH=`IMG_WIDTH;
  parameter PIXEL_SIZE=`PIXEL_SIZE;
  parameter ROWS=`RF_HEIGHT;
  parameter COLS=`RF_WIDTH;
  parameter RF_CENTER_X=`RF_CENTER_X;
  parameter RF_CENTER_Y=`RF_CENTER_Y;
  localparam RF_SIZE=ROWS*COLS;
  localparam IMG_SIZE=IMG_HEIGHT*IMG_WIDTH;
  localparam WORDS_PER_IMG=(IMG_SIZE+WORD_BITS-1)/WORD_BITS;
  localparam ADDR_INIT=((`RF_CENTER_Y-(`RF_WIDTH/2))*IMG_WIDTH)+
                                                (`RF_CENTER_X-(`RF_HEIGHT/2));

  input  logic rst_n, addr_clear, clk;
  input  logic [WORD_BITS-1:0] mem_word;
  input  logic                 data_valid, filter_ready;
  output logic [ADDR_BITS-1:0] addr;
  output logic out_valid;
  output logic [ROWS - 1:0][COLS - 1:0][PIXEL_SIZE-1:0] rf;

  logic [ADDR_BITS - 1:0] next_addr, addr_offset;
  enum logic [1:0] {HOLD = 2'd0, INC_COL=2'd1, 
                              INC_ROW=2'd2, INC_IMG=2'd3} sel_addr_offset;
  logic addr_c_out;
  logic [$clog2(ROWS) - 1:0] row_count;
  logic [$clog2(COLS) - 1:0] col_count;

  // Control signals
  logic clear_row_count, clear_col_count;
  logic en_row_count, en_col_count;
  logic valid;

  enum logic [1:0] {RESET, ITER, WAIT, DONE} state, next_state;

  always_ff @(posedge clk or negedge rst_n) begin : proc_state
    if(~rst_n) begin
      state <= RESET;
    end else begin
      state <= next_state;
    end
  end

  // FSM, control signal and next state logic
  always_comb begin
    en_row_count = 1'b0;
    clear_row_count = 1'b0;
    en_col_count = 1'b0;
    clear_col_count = 1'b0;
    sel_addr_offset = HOLD;
    valid = 1'b0;
    case (state)
      RESET: begin
        if (data_valid) begin
          next_state = ITER;
          en_col_count = 1'b1;
          sel_addr_offset = INC_COL;
        end else begin
          next_state = RESET;
        end
      end
      ITER: begin
        if (data_valid) begin
          if (col_count == COLS - 1 && row_count != ROWS - 1) begin
            next_state = ITER;
            clear_col_count = 1'b1;
            en_row_count = 1'b1;
            sel_addr_offset = INC_ROW;
          end else if (col_count == COLS - 1 && row_count == ROWS - 1) begin
            if (filter_ready) begin
              next_state = ITER;
              clear_col_count = 1'b1;
              clear_row_count = 1'b1;
              sel_addr_offset = INC_IMG;
              valid = 1'b1;
            end else begin
              next_state = WAIT;
              valid = 1'b1;
            end 
          end else begin
            next_state = ITER;
            en_col_count = 1'b1;
            sel_addr_offset = INC_COL;
          end
        end else begin
          next_state = WAIT;
        end
      end
      WAIT: begin
        if (data_valid) begin
          if (col_count == COLS - 1 && row_count != ROWS - 1) begin
            next_state = ITER;
            clear_col_count = 1'b1;
            en_row_count = 1'b1;
            sel_addr_offset = INC_ROW;
          end else if (col_count == COLS - 1 && row_count == ROWS - 1) begin
            if (filter_ready) begin
              next_state = ITER;
              clear_col_count = 1'b1;
              clear_row_count = 1'b1;
              sel_addr_offset = INC_IMG;
              valid = 1'b1;
            end else begin
              next_state = WAIT;
              valid = 1'b1;
            end
          end else begin
            next_state = ITER;
            en_col_count = 1'b1;
            sel_addr_offset = INC_COL;
          end
        end else begin
          next_state = WAIT;
        end
      end
      DONE: begin
        next_state = DONE;
      end
    endcase
  end

  // Counter to write enable a certain column in the rf buffer
  counter    #( .WIDTH($clog2(COLS))) 
  col_counter ( .rst_n,
                .clk,
                .clear(clear_col_count), 
                .count(col_count), 
                .en(en_col_count));

  // Counter to write enable a certain row in the rf buffer
  counter    #( .WIDTH($clog2(ROWS))) 
  row_counter ( .rst_n,
                .clk,
                .clear(clear_row_count), 
                .count(row_count), 
                .en(en_row_count));

  // Register that hold previously requested pixel address
  register   #( .WIDTH(ADDR_BITS),
                .RST_VAL(ADDR_INIT),
                .CLEAR_VAL(ADDR_INIT))
  address_reg ( .rst_n,
                .clk,
                .clear(addr_clear),
                .en(1'b1),
                .D(next_addr),
                .Q(addr));

  // Mux to select what offset to add to current pixel address, to get the 
  // next pixel
  mux        #( .DATA_SIZE(ADDR_BITS),
                .NUM_INPUTS(4))
  sel_offset  ( .in({(IMG_SIZE - (COLS - 1) - ((ROWS - 1) * IMG_WIDTH)),
                     (IMG_WIDTH - COLS + 1), 
                     32'd1, 
                     32'd0}),
                .sel(sel_addr_offset),
                .out(addr_offset));

  // Adder to calculate next address to request from memory
  adder      #( .DATA_SIZE(ADDR_BITS))
  addr_calc   ( .A(addr),
                .B(addr_offset),
                .S(next_addr),
                .C(addr_c_out));

  // A 2D pixel buffer
  buffer     #( .ROWS(`RF_HEIGHT),
                .COLS(`RF_WIDTH),
                .PIXEL_SIZE(PIXEL_SIZE),
                .WORD_BITS(`MEM_WORD_BITS))
  img_out     ( .rst_n,
                .clk,
                .row_sel(row_count),
                .col_sel(col_count),
                .mem_word,
                .data_valid,
                .buff(rf));

  // Register to buffer out_valid, so that out_valid is asstered the same cycle
  // that the rf buffer holds valid data.
  register   #( .WIDTH(1))
  valid_reg   ( .rst_n,
                .clk,
                .clear(1'b0),
                .en(1'b1),
                .D(valid),
                .Q(out_valid));
endmodule : receptive_field 

/**
 * This module simply holds the pixel data read from memory. The output of this
 * module is fed directly to the downstream filters.
 *
 * Inputs:
 *  - rst_n: Asynchronous reset signal (active low)
 *  - clk: Clock signal into the module
 *  - row_sel: Which row in the buffer to enable writing
 *  - col_sel: Which column in the buffer to enable writing
 *  - mem_word: The data being written to a cell in the buffer
 *  - data_valid: To be asserted if mem_word contains valid data 
 * Outputs:
 *  - buff: The output buffer array
 */
module buffer (rst_n, clk, row_sel, col_sel, mem_word, data_valid, buff);
  parameter ROWS=`RF_HEIGHT;
  parameter COLS=`RF_WIDTH;
  parameter PIXEL_SIZE=`PIXEL_SIZE;
  parameter WORD_BITS=`MEM_WORD_BITS;

  input logic  rst_n, clk, data_valid;
  input logic  [$clog2(ROWS) - 1:0] row_sel;
  input logic  [$clog2(COLS) - 1:0] col_sel;
  input logic  [WORD_BITS - 1:0] mem_word;
  output logic [ROWS - 1:0][COLS - 1:0][PIXEL_SIZE - 1:0] buff;

  logic [ROWS - 1:0] en_row;
  logic [COLS - 1:0] en_col;
  logic [ROWS - 1:0][COLS - 1:0] en_buff;

  genvar i, j;
  generate
    // Create row enable control signals
    for (i = 0; i < ROWS; i++)
      assign en_row[i] = i == row_sel;

    // Create column enable control signals
    for (j = 0; j < COLS; j++)
      assign en_col[j] = j == col_sel;

    // Create register array for receptive field buffer
    for (i = 0; i < ROWS; i++) begin 
      for (j = 0; j < COLS; j++) begin
        assign en_buff[i][j] = en_row[i] && en_col[j] && data_valid;
        register #(.WIDTH(WORD_BITS)) 
        buff_cell (.rst_n, 
                   .clk, 
                   .clear(1'b0), 
                   .en(en_buff[i][j]),
                   .D(mem_word),
                   .Q(buff[i][j]));
      end
    end
  endgenerate
endmodule
`endif /* _RECEPTIVE_FIELD_SV_ */
