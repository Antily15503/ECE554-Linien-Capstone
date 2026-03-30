`default_nettype none

// control.sv - sequence execution FSM
//
// reads block parameters from reg_file (1-cycle sync read latency),
// loads them into the active functional block via a shared param bus,
// then starts the block and waits for its done signal.
//
// integration notes:
//   - i_num_blocks is the INDEX of the last block (0 = one block, 15 = sixteen).
//     the PS writes this convention via regfile_adapter.num_blocks.
//   - i_init_v_drive comes from ttl_handler.o_saved_dac_out (DAC_WIDTH).
//   - o_active is high from FETCH_TYPE through CAPTURE_VDRIVE. it drops in DONE.
//     the DAC mux should use ttl_handler.o_active (which stays high until seq_done
//     is acknowledged) to avoid a 1-cycle glitch.
//   - o_seq_done pulses for 1 cycle in the DONE state. ttl_handler latches this.

module control #(
    // parameters
    parameter MAX_BLOCKS = 16,
    parameter DATA_WIDTH = 32,
    parameter DAC_WIDTH  = 14,

    localparam NUM_BLOCK_TYPES = 6,
    localparam MAX_BLOCK_PARAMS = 7,     // max params any block type needs (chirp=6)
    localparam REGFILE_ADDR_WIDTH = 8,

    // auto-calculated
    localparam int BLOCK_IDX_WIDTH      = $clog2(MAX_BLOCKS),
    localparam int PARAM_IDX_WIDTH      = $clog2(MAX_BLOCK_PARAMS),
    localparam int BLOCK_TYPE_IDX_WIDTH = $clog2(NUM_BLOCK_TYPES)
) (
    input logic clk,
    input logic rst_n,

    // top level control inputs
    input logic                         i_start,          // one cycle pulse from ttl_handler
    input logic [BLOCK_IDX_WIDTH-1:0]   i_num_blocks,     // last block index (0 = one block)
    input logic [      DAC_WIDTH-1:0]   i_init_v_drive,   // ttl snapshot starting voltage

    // reg_file read port
    output logic [REGFILE_ADDR_WIDTH-1:0] o_regfile_addr,
    input  logic [        DATA_WIDTH-1:0] i_regfile_data,

    // functional block done + drive (active block selected by cur_type)
    input  logic [NUM_BLOCK_TYPES-1:0]    i_block_done,
    input  logic [DAC_WIDTH-1:0]          i_block_drive [NUM_BLOCK_TYPES],

    // shared param bus to functional blocks
    output logic [DATA_WIDTH-1:0]         o_param_data,
    output logic [3:0]                    o_param_addr,
    output logic                          o_param_wr_en,

    // per-block one-hot enable and start signals
    output logic [NUM_BLOCK_TYPES-1:0]    o_block_en,
    output logic [NUM_BLOCK_TYPES-1:0]    o_block_start,

    // DAC output
    output logic [DAC_WIDTH-1:0]          v_drive,

    // control outputs (to ttl_handler / relock)
    output logic                          o_seq_done,
    output logic                          o_active
);

  // ========================= FSM encoding ==============================
  typedef enum logic [2:0] {
    IDLE           = 3'b000,
    FETCH_TYPE     = 3'b001,  // issue reg_file read for block type
    LOAD_INIT      = 3'b010,  // latch type, issue read for first param
    LOAD_PARAMS    = 3'b011,  // write params to block, 1 per cycle
    START_BLOCK    = 3'b100,  // one-cycle start pulse (param_wr guaranteed low)
    WAIT_DONE      = 3'b101,  // block executing, wait for done
    CAPTURE_VDRIVE = 3'b110,  // latch final drive, advance block index
    DONE           = 3'b111   // pulse seq_done, return to idle
  } state_t;
  state_t state, next_state;

  // ========================= Internal Registers ==============================
  logic [BLOCK_IDX_WIDTH-1:0]      block_idx;      // "program counter"
  logic [PARAM_IDX_WIDTH-1:0]      param_idx;      // current param being loaded
  logic [DAC_WIDTH-1:0]            prev_v_drive;    // voltage to hold between blocks
  logic [BLOCK_TYPE_IDX_WIDTH-1:0] cur_type;        // current block type (opcode)

  // ========================= Comb. Intermediates ==============================
  logic [NUM_BLOCK_TYPES-1:0]         type_onehot;
  logic                               active_block_done;
  logic [DAC_WIDTH-1:0]               active_block_drive;
  logic [PARAM_IDX_WIDTH-1:0]         num_params;
  logic                               last_param, last_block;
  logic [REGFILE_ADDR_WIDTH-1:0]      block_base_addr;

  // ========================= Current Block Calculations ==============================
  assign block_base_addr   = {1'b0, block_idx, 3'b000};      // block_idx * 8
  assign type_onehot       = NUM_BLOCK_TYPES'(1) << cur_type;
  assign active_block_done = i_block_done[cur_type];
  assign active_block_drive = i_block_drive[cur_type];

  // param count LUT — how many params each block type needs
  //   type 0 (delay):       2  (hold_voltage, duration)
  //   type 1 (linear_ramp): 3  (v_start, step_size, duration)
  //   type 2 (direct_jump): 2  (target_voltage, duration)
  //   type 3 (chirp):       6  (start_f, end_f, amplitude, dc_offset, phase_inc, duration)
  //   type 4 (sinusoid):    6  (v_mid, v_amp, v_min_cut, v_max_cut, phase_inc, duration)
  //   type 5 (arb_wfm):     4  (clk_div, length, start_addr, duration)
  always_comb begin
    case (cur_type)
      3'd0:    num_params = 3'd2;
      3'd1:    num_params = 3'd3;
      3'd2:    num_params = 3'd2;
      3'd3:    num_params = 3'd6;
      3'd4:    num_params = 3'd6;  // was 5, fixed: sinusoid needs all 6
      3'd5:    num_params = 3'd4;
      default: num_params = 3'd1;
    endcase
  end

  // boundary flags
  assign last_param = (param_idx == (num_params - PARAM_IDX_WIDTH'(1)));
  assign last_block = (block_idx == i_num_blocks);

  // ========================= FSM Next-State Logic ==============================
  always_comb begin
    next_state = state;

    case (state)
      IDLE: begin
        if (i_start) next_state = FETCH_TYPE;
      end
      FETCH_TYPE:  next_state = LOAD_INIT;
      LOAD_INIT:   next_state = LOAD_PARAMS;
      LOAD_PARAMS: begin
        if (last_param) next_state = START_BLOCK;
      end
      START_BLOCK: next_state = WAIT_DONE;
      WAIT_DONE: begin
        if (active_block_done) next_state = CAPTURE_VDRIVE;
      end
      CAPTURE_VDRIVE: begin
        if (last_block) next_state = DONE;
        else            next_state = FETCH_TYPE;
      end
      DONE:    next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // state register (async reset)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  // ========================= Datapath Registers (sync reset) ==============================
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      block_idx    <= '0;
      param_idx    <= '0;
      prev_v_drive <= '0;
      cur_type     <= '0;
    end else begin
      case (state)
        IDLE: begin
          if (i_start) begin
            block_idx    <= '0;
            param_idx    <= '0;
            prev_v_drive <= i_init_v_drive;
          end
        end

        FETCH_TYPE: begin
          param_idx <= '0;
        end

        LOAD_INIT: begin
          cur_type <= i_regfile_data[BLOCK_TYPE_IDX_WIDTH-1:0];
        end

        LOAD_PARAMS: begin
          if (!last_param)
            param_idx <= param_idx + PARAM_IDX_WIDTH'(1);
        end

        START_BLOCK: begin
          // no datapath updates
        end

        WAIT_DONE: begin
          // block is running
        end

        CAPTURE_VDRIVE: begin
          prev_v_drive <= active_block_drive;
          if (!last_block)
            block_idx <= block_idx + BLOCK_IDX_WIDTH'(1);
        end

        DONE: begin
          block_idx <= '0;
          param_idx <= '0;
        end
      endcase
    end
  end

  // ========================= Reg-File Address Generation ==============================
  always_comb begin
    case (state)
      FETCH_TYPE:  o_regfile_addr = block_base_addr;                                         // offset 0: type
      LOAD_INIT:   o_regfile_addr = block_base_addr + 8'd1;                                  // offset 1: first param (arrives next cycle)
      LOAD_PARAMS: o_regfile_addr = block_base_addr + 8'd2 + REGFILE_ADDR_WIDTH'(param_idx); // offset 2+: next param
      default:     o_regfile_addr = '0;
    endcase
  end

  // ========================= Output Logic ==============================
  always_comb begin
    // defaults
    o_param_data  = '0;
    o_param_addr  = '0;
    o_param_wr_en = 1'b0;
    o_block_en    = '0;
    o_block_start = '0;
    v_drive       = prev_v_drive;
    o_seq_done    = 1'b0;
    o_active      = 1'b0;

    case (state)
      IDLE: begin
        // everything at defaults
      end

      FETCH_TYPE: begin
        o_active = 1'b1;
      end

      LOAD_INIT: begin
        o_active = 1'b1;
      end

      LOAD_PARAMS: begin
        o_active      = 1'b1;
        o_block_en    = type_onehot;
        o_param_addr  = 4'(param_idx);
        o_param_data  = i_regfile_data;   // data from previous cycle's read
        o_param_wr_en = 1'b1;
      end

      START_BLOCK: begin
        o_active      = 1'b1;
        o_block_en    = type_onehot;
        o_block_start = type_onehot;
        v_drive       = active_block_drive;
      end

      WAIT_DONE: begin
        o_active   = 1'b1;
        o_block_en = type_onehot;
        v_drive    = active_block_drive;
      end

      CAPTURE_VDRIVE: begin
        o_active   = 1'b1;
        o_block_en = type_onehot;
        v_drive    = active_block_drive;
      end

      DONE: begin
        o_seq_done = 1'b1;
        // o_active intentionally 0 here. DAC mux uses ttl_handler.o_active
        // which stays high until it processes seq_done.
      end

      default: begin
        // safety
      end
    endcase
  end

endmodule
`default_nettype wire