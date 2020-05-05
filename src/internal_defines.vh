`ifndef _INTERNAL_DEFINES_VH_
`define _INTERNAL_DEFINES_VH_

//`define SIM

`define TIME_PERIOD             8 // Number of clk cycles spikes could occur in

`define IMG_WIDTH               28
`define IMG_HEIGHT              28
`define PIXEL_SIZE              8 // Number of bits that represent a pixel
`define FILTER_PADDING_RADIUS   2

`define RF_WIDTH                3 // Number of pixels in a row of the image
`define RF_HEIGHT               3 // Number of pixels in a col of the image
`define RF_CENTER_X             13
`define RF_CENTER_Y             13

`define NEURONS_PER_COLUMN      16
`define NEURON_THRESHOLD        16

`define NUM_WINNERS             1

`define STDP_MYU_WIDTH          7
`define STDP_MYU_CAPTURE        10
`define STDP_MYU_MINUS          10
`define STDP_MYU_SEARCH         1
`define STDP_MYU_BACKOFF        96
`define STDP_MYU_MIN            4

`define MEM_ADDR_BITS           32
`define MEM_WORD_BITS           8

typedef enum int {ON, OFF} filter_type;

`endif /* _INTERNAL_DEFINES_VH */
