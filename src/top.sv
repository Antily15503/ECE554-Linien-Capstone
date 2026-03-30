`default_nettype none

module sequence_top #(
    parameter int MAX_BLOCKS = 16,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_BLOCK_TYPES = 6,
    parameter int REGFILE_ADDR_WIDTH = 8,

    //auto-calculated parameters
    localparam int BLOCK_IDX_WIDTH = $clog2(MAX_BLOCKS),
    localparam int BLOCK_TYPE_IDX_WIDTH = $clog2(NUM_BLOCK_TYPES)
) (
    input logic clk,
    input logic rst_n,

    //Signals from Regfile_Adapter (PS write to reg_file)
    input logic [REGFILE_ADDR_WIDTH-1:0] i_reg_wr_addr,
    input logic [DATA_WIDTH-1:0] i_reg_wr_data,
    input logic i_reg_wr_en,

    //Signal from Regfile_Adapter (config)
    input logic [BLOCK_IDX_WIDTH-1:0] i_num_blocks,   //last block index

    //signals from ttl handler
    input logic                     i_start,         //in ttl_handler, this is o_fsm_start
    input logic [13:0]              i_init_v,        //saved DAC voltage

    //Signals to ttl handler
    output logic                    o_seq_done,      //1 cycle pulse
    output logic                    o_active,        //high when sequence is active

    //DAC output (to linien)
    output logic [13:0]             o_dac_drive
);

//Internal Wires

//reg file read port (control to reg_file)
logic [REGFILE_ADDR_WIDTH-1:0] reg_rd_addr;
logic [DATA_WIDTH-1:0] reg_rd_data;

//shared param bus (control to all blocks)
logic [DATA_WIDTH-1:0] param_bus_data;
logic [3:0] param_bus_addr;
logic param_bus_wr_en;
logic [NUM_BLOCK_TYPES-1:0] block_en;
logic [NUM_BLOCK_TYPES-1:0] block_active;

//feedback from blocks to control
logic [13:0] block_drive [NUM_BLOCK_TYPES];


// input signals:  clk, rst_n
//                 ps write signals (i_ps_wr_addr, i_ps_wr_data, i_ps_wr_en)
// output signals: 
reg_file #(
        .ADDR_WIDTH (REGFILE_ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_reg_file (
        .clk        (clk),

        // PS write port
        .i_wr_addr  (i_reg_wr_addr),
        .i_wr_data  (i_reg_wr_data),
        .i_wr_en    (i_reg_wr_en),

        // Control read port
        .i_rd_addr  (reg_rd_addr),
        .o_rd_data  (reg_rd_data)
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
    .i_init_v_drive (i_init_v),

    // Register file read port
    .o_regfile_addr (reg_rd_addr),
    .i_regfile_data (reg_rd_data),

    // Function block drive (no more i_block_done!)
    .i_block_drive  (block_drive),

    // Shared parameter bus
    .o_param_data   (param_bus_data),
    .o_param_addr   (param_bus_addr),
    .o_param_wr_en  (param_bus_wr_en),

    // Per-block control
    .o_block_en     (block_en),
    .o_block_active (block_active),

    // DAC output
    .v_drive        (o_dac_drive),

    // Status
    .o_seq_done     (o_seq_done),
    .o_active       (o_active)
);

// Delay Block (type 0)
//TODO: update with fixed delay.sv interface
delay #(
    .DATA_WIDTH (DATA_WIDTH)
) u_delay (
    .clk            (clk),
    .rst_n          (rst_n),
    .i_param_addr   (param_bus_addr),
    .i_param_data   (param_bus_data),
    .i_en           (block_en[0]),
    .i_start        (block_active[0]),
    .i_wren         (param_bus_wr_en && block_en[0]),
    .o_drive        (block_drive[0])
);

//TODO: Linear Ramp Block

//TODO: Direct jump block

//TODO: Chirp block

//TODO: AWG block

//Sinusoidal Block (type 4)
sinusoid #(
    .DATA_WIDTH (DATA_WIDTH)
) u_sinusoid (
    .clk            (clk),
    .rst_n          (rst_n),
    .i_param_addr   (param_bus_addr),
    .i_param_data   (param_bus_data),
    .i_wren         (param_bus_wr_en && block_en[4]),
    .i_start        (block_active[4]),
    .i_en           (block_en[4]),
    .o_drive        (block_drive[4])
);
    
endmodule

`default_nettype wire