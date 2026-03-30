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

    //Signals from Regfile_Adapter (PS write to reg_file)
    input logic [REGFILE_ADDR_WIDTH-1:0] i_rf_wr_addr,
    input logic [DATA_WIDTH-1:0] i_rf_wr_data,
    input logic i_rf_wr_en,

    //Signal from Regfile_Adapter (config)
    input logic [BLOCK_IDX_WIDTH-1:0] i_num_blocks,   //last block index

    //signals from ttl handler
    input logic                     i_start,         //in ttl_handler, this is o_fsm_start
    input logic [13:0]              i_init_v         //saved DAC voltage

    //Signals to ttl handler
    output logic                    o_seq_done,      //1 cycle pulse
    output logic                    o_active,        //high when sequence is active
    
    //DAC output (to linien)
    output logic [13:0]             o_dac_drive 
);

//Internal Wires

//reg file read port (control to reg_file)
logic [REGFILE_ADDR_WIDTH-1:0] rf_rd_addr;
logic [DATA_WIDTH-1:0] rf_rd_data;

//shared param bus (control to all blocks)
logic [NUM_BLOCK_TYPES-1:0] block_en;
logic [NUM_BLOCK_TYPES-1:0] block_start;

//feedback from blocks to control
logic [13:0] block_drive [NUM_BLOCK_TYPES];


// input signals:  clk, rst_n
//                 ps write signals (i_ps_wr_addr, i_ps_wr_data, i_ps_wr_en)
// output signals: 
reg_file #(
        .ADDR_WIDTH (REGFILE_ADDR_W),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_reg_file (
        .clk        (clk),

        // PS write port
        .i_wr_addr  (i_ps_wr_addr),
        .i_wr_data  (i_ps_wr_data),
        .i_wr_en    (i_ps_wr_en),

        // Control read port
        .i_rd_addr  (ctrl_rd_addr),
        .o_rd_data  (ctrl_rd_data)
    );


control #(
    .MAX_BLOCKS (MAX_BLOCKS),
    .DATA_WIDTH (DATA_WIDTH)
) u_control (
    .clk            (clk),
    .rst_n          (rst_n),

    // Top-level control
    .i_start        (i_start),
    .i_num_blocks   (i_num_blocks),
    .i_init_drive   (i_init_drive),

    // Register file read port
    .o_regfile_addr (ctrl_rd_addr),
    .i_regfile_data (ctrl_rd_data),

    // Function block feedback
    .i_block_done   (i_block_done),
    .i_block_drive  (i_block_drive),

    // Shared parameter bus
    .o_param_data   (o_param_data),
    .o_param_addr   (o_param_addr),
    .o_param_wr     (o_param_wr),

    // Per-block control
    .o_en           (o_en),
    .o_start        (o_start),

    // DAC output
    .o_drive        (o_drive),

    // Status
    .o_seq_done     (o_seq_done),
    .o_active       (o_active),
    .o_cur_block    (o_cur_block)
);

// Delay Block
//TODO: update with fixed delay.sv
delay #(
    .DATA_WIDTH (DATA_WIDTH),
    .DAC_WIDTH (DAC_WIDTH)
) u_delay (
    .clk        (clk),
    .rst_n      (rst_n),
    .

);

//TODO: Linear Ramp Block

//TODO: Direct jump block

//TODO: Chirp block

//TODO: AWG block

//Sinusoidal Block
sinusoid #(
    .DATA_WIDTH (DATA_WIDTH),
    .DAC_WIDTH (DAC_WIDTH)
) u_sinusoid (
    .clk        (clk),
    .rst_n      (rst_n),
    .i_param_addr (param_addr),
    .i_param_data (param_data),
    .i_wren (param_wr_en & block_en[4]),
    .i_start (block_start[4]),
    .i_en (block_en[4]),
    .o_done (block_done[4]),
    .o_drive (block_drive[4])
);
    
endmodule

`default_nettype wire