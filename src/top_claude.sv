`default_nettype none
////////////////////////////////////////////////////////////////////////////////
// sequence_top.sv — Top-level wrapper wiring control + reg_file
//
// Instantiates the control FSM and register file, connects their internal
// signals, and exposes external ports for:
//   - PS/AXI register writes (pre-experiment configuration)
//   - ttl_handler interface (start, done, active)
//   - Function block interfaces (param bus, enable, start, done, drive)
//   - DAC output
//
// Function blocks are NOT instantiated here — they connect via ports.
// This keeps the wrapper thin and lets blocks be added/swapped independently.
////////////////////////////////////////////////////////////////////////////////

module sequence_top #(
    parameter int MAX_BLOCKS = 16,
    parameter int DATA_WIDTH = 32,

    localparam int NUM_BLOCK_TYPES = 6,
    localparam int BLOCK_IDX_WIDTH = $clog2(MAX_BLOCKS),
    localparam int REGFILE_ADDR_W  = 8
) (
    input  logic                        clk,
    input  logic                        rst_n,

    // --- ttl_handler interface ---
    input  logic                        i_start,        // one-cycle pulse: begin sequence
    input  logic [DATA_WIDTH-1:0]       i_init_drive,   // starting voltage from snapshot
    output logic                        o_seq_done,     // one-cycle pulse: sequence complete
    output logic                        o_active,       // level: high while running

    // --- PS / AXI configuration (pre-experiment) ---
    input  logic [REGFILE_ADDR_W-1:0]   i_ps_wr_addr,
    input  logic [DATA_WIDTH-1:0]       i_ps_wr_data,
    input  logic                        i_ps_wr_en,
    input  logic [BLOCK_IDX_WIDTH-1:0]  i_num_blocks,   // sequence length - 1

    // --- function block interfaces (active block selected by o_en) ---
    input  logic [NUM_BLOCK_TYPES-1:0]  i_block_done,
    input  logic [DATA_WIDTH-1:0]       i_block_drive [NUM_BLOCK_TYPES],
    output logic [DATA_WIDTH-1:0]       o_param_data,
    output logic [4:0]                  o_param_addr,
    output logic                        o_param_wr,
    output logic [NUM_BLOCK_TYPES-1:0]  o_en,
    output logic [NUM_BLOCK_TYPES-1:0]  o_start,

    // --- DAC output ---
    output logic [DATA_WIDTH-1:0]       o_drive,

    // --- status / monitoring ---
    output logic [BLOCK_IDX_WIDTH-1:0]  o_cur_block
);

    // =========================================================================
    // Internal wires: control ↔ reg_file
    // =========================================================================
    logic [REGFILE_ADDR_W-1:0] ctrl_rd_addr;
    logic [DATA_WIDTH-1:0]     ctrl_rd_data;

    // =========================================================================
    // Register file
    // =========================================================================
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

    // =========================================================================
    // Control FSM
    // =========================================================================
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

endmodule
`default_nettype wire
