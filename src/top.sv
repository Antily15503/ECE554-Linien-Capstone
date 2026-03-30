`default_nettype none

module sequence_top #(
    parameter int MAX_BLOCKS = 16,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_BLOCK_TYPES = 6,
    parameter int REGFILE_ADDR_WIDTH = 8, 

    //auto-calculated parameters
    localparam int BLOCK_IDX_WIDTH = $clog2(MAX_BLOCKS),
    localparam int BLOCK_TYPE_IDX_WIDTH = $clog2(NUM_BLOCK_TYPES),
    localparam int 
) (
    input logic clk,
    input logic rst_n,

    //signals from ttl handler
    input logic                     i_start,         //in ttl_handler, this is o_fsm_start
    
    //signals from CSRs
    init logic [DATA_WIDTH-1:0]     i_init_voltage,  //in linien CSR: limit_fast1.y
    output                          logic 
);

endmodule

`default_nettype wire