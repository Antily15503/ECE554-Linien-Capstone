`default_nettype none



module control #(
    //parameters we change
    parameter MAX_BLOCKS = 16,
    parameter DATA_WIDTH = 32,
    parameter DAC_WIDTH  = 14,
    localparam NUM_BLOCK_TYPES = 6,
    localparam MAX_BLOCK_PARAMS = 5,
    localparam REGFILE_ADDR_WIDTH = 8,

    //auto-calculated parameters
    localparam int BLOCK_IDX_WIDTH = $clog2(MAX_BLOCKS),
    localparam int PARAM_IDX_WIDTH = $clog2(MAX_BLOCK_PARAMS),
    localparam int BLOCK_TYPE_IDX_WIDTH = $clog2(NUM_BLOCK_TYPES)
) (
    input  logic clk,
    input  logic rst_n,

    //top level control inputs
    input  logic                            i_start,         //one cycle pulse
    input  logic [BLOCK_IDX_WIDTH-1:0]      i_num_blocks,    //how long the instruction is
    input  logic [DATA_WIDTH-1:0]           i_init_v_drive,  //ttl snapshot starting voltage

    //In-Out signals from register read port      
    output logic [REGFILE_ADDR_WIDTH-1:0]   o_regfile_addr,  //which address to read register from
    input  logic [DATA_WIDTH-1:0]           i_regfile_data,  //data from register

    //inputs from functional blocks (one hot, we only poll from the one-hot active module via idx)
    input  logic [NUM_BLOCK_TYPES-1:0]      i_block_done,
    input  logic [DATA_WIDTH-1:0]           i_block_drive [NUM_BLOCK_TYPES], //again, one hot. Only one of the i_block_drive will be looked at

    //shared output param bus. Only one module will listen for this signal during loading
    output logic [DATA_WIDTH-1:0]           o_param_data,
    output logic [3:0]                      o_param_addr,    //basically which parameter is specified at current transaction.
    output logic                            o_param_wr_en,   //write enabled? (is current value in o_param_data valid)

    //per-block one-hot enable and start signals
    output logic [NUM_BLOCK_TYPES-1:0] o_block_en,
    output logic [NUM_BLOCK_TYPES-1:0] o_block_start,

    //DAC OUTPUT: V_DRIVE
    output logic [DAC_WIDTH-1:0] v_drive,

    //Control output signals (to relock)
    output o_seq_done,
    output o_active
)

    // ========================= FSM encoding ==============================
        typedef enum logic [2:0] {
            IDLE           = 3'b000,
            FETCH_TYPE     = 3'b001,   // issue reg_file read for block type
            LOAD_INIT      = 3'b010,   // latch type, issue read for first param
            LOAD_PARAMS    = 3'b011,   // write params to block, 1 per cycle
            START_BLOCK    = 3'b100,   // one-cycle start pulse (param_wr guaranteed low)
            WAIT_DONE      = 3'b101,   // block executing, wait for done
            CAPTURE_VDRIVE = 3'b110,   // latch final drive, advance block index
            DONE           = 3'b111    // pulse seq_done, return to idle
        } state_t;
        state_t state, next_state;
    // ========================= Internal Registers ==============================
        logic [BLOCK_IDX_WIDTH-1:0] block_idx; //"program counter"
        logic [PARAM_IDX_WIDTH-1:0] param_idx; //specifies what parameter is being written to when writing parameters
        logic [DATA_WIDTH-1:0]      prev_v_drive; //in case we need to hold drive voltage, tracks the voltage previously left off
        logic [BLOCK_TYPE_IDX_WIDTH-1:0]      cur_type; //tracks current instruction block type (similar to opcode)
    
    // ========================= Comb. Intermediates ==============================
        logic [NUM_BLOCK_TYPES-1:0] type_onehot;
        logic active_block_done; //from input
        logic [DATA_WIDTH-1:0] active_block_drive; //intermediate for determining v_drive
        logic [PARAM_IDX_WIDTH-1:0] num_params; //how many parameters does current block require
        logic last_param, last_block; //flags
        logic [REGFILE_ADDR_WIDTH-1:0] block_base_addr;
    
    // ========================= Current Block Calculations + Parameters ==============================
        assign block_base_addr = {1'b0, block_idx, 3'b000};
        assign type_onehot = NUM_BLOCK_TYPES'(1) << cur_type;
        assign active_block_done = i_block_done[cur_type];
        assign active_block_drive = i_block_drive[cur_type];

        //mini lut for instructions and param amts
        always_comb begin
            case (cur_type)
                3'd0: num_params = 3'd2; //delay module: hold_voltage + duration
                3'd1: num_params = 3'd3; //linear_ramp: v_from, v_to, duration
                3'd2: num_params = 3'd2; //direct_jump: target_v, duration
                3'd3: num_params = 3'd6; //chirp_gen: start_f, end_f, idk I'll just give it 6 slots for now
                3'd4: num_params = 3'd5; //sinusoid: freq, amp, dc, duration, phase
                3'd5: num_params = 3'd4; //arb_waveform: clk_div, length, start_addr, duration
                default: num_params = 3'd1; //default
            endcase
        end

        //boundary flags
        assign last_param = (param_idx == (num_params - PARAM_IDX_WIDTH'(1)));
        assign last_block = (block_idx == i_num_blocks);

    // ========================= FSM Logic ==============================
        //next state logic ONLY. Very barebones (intentional)
        always_comb begin
            next_state = state;

            case (state)
                IDLE: begin
                        if (i_start) begin
                        next_state = FETCH_TYPE;
                    end
                end
                FETCH_TYPE: next_state = LOAD_INIT;
                LOAD_INIT: next_state = LOAD_PARAMS;
                LOAD_PARAMS: begin if (last_param) begin
                        next_state = START_BLOCK;
                    end
                end
                START_BLOCK: next_state = WAIT_DONE;
                WAIT_DONE: begin if (active_block_done) begin
                        next_state = CAPTURE_VDRIVE;
                    end
                end
                CAPTURE_VDRIVE: begin if (last_block) begin
                        next_state = DONE;
                    end else begin
                        next_state = FETCH_TYPE;
                    end
                end
                DONE: next_state = IDLE;
                default: next_state = IDLE;
            endcase
        end

        //state register
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) state <= IDLE;
            else state <= next_state;
        end

    // ========================= FSM Datapath Registers Handler. Sync Reset ==============================
        always_ff @(posedge clk) begin
            if (!rst_n) begin
                block_idx <= '0;
                param_idx <= '0;
                prev_v_drive <= '0;
                cur_type <= '0;
            end else begin
                case (state)
                    IDLE: begin
                        //idle, keep critical data at reset to avoid switching
                        if (i_start) begin
                            block_idx <= '0;
                            param_idx <= '0;
                            prev_v_drive <= i_init_v_drive;
                        end
                    end

                    FETCH_TYPE: begin
                        //rd_address was asserted in combinational logic
                        //rd_data will arrive next clk cycle (LOAD_INIT), so just reset param_idx for upcoming LOAD
                        param_idx <= '0;
                    end

                    LOAD_INIT: begin
                        //rd_data now holds block type
                        cur_type <= i_regfile_data[BLOCK_TYPE_IDX_WIDTH-1:0];
                    end

                    LOAD_PARAMS: begin
                        //stay at this state until we're done loading all necessary parameters
                        if (!last_param) param_idx <= param_idx + PARAM_IDX_WIDTH'(1);
                    end

                    START_BLOCK: begin
                        // timing gap, no datapath updates needed
                    end

                    WAIT_DONE: begin
                        // Block is running, no datapath updates needed
                    end

                    CAPTURE_VDRIVE: begin
                        //update prev_v_drive to last driven voltage value, increment block
                        prev_v_drive <= active_block_drive;
                        if (!last_block) begin
                            block_idx <= block_idx + BLOCK_IDX_WIDTH'(1);
                        end
                    end

                    DONE: begin
                        //done, reset things
                        block_idx <= '0;
                        param_idx <= '0;
                    end
                endcase
            end
        end
    // ========================= FSM Register Address Handler ==============================
        always_comb begin
            case (state)
                FETCH_TYPE:  o_regfile_addr = block_base_addr;
                LOAD_INIT:   o_regfile_addr = block_base_addr + 8'd1;
                LOAD_PARAMS: o_regfile_addr = block_base_addr + 8'd2 + REGFILE_ADDR_WIDTH'(param_idx);
                default:     o_regfile_addr = '0;
            endcase
        end
    
    // ========================= FSM Output Logic ==============================
        always_comb begin
            //default or init values
            o_param_data = '0;
            o_param_addr = '0;
            o_param_wr_en = '0;
            o_block_en = '0;
            o_block_start = '0;
            v_drive = prev_v_drive[DAC_WIDTH-1:0];

            o_seq_done = 1'b0;
            o_active = 1'b0;
            
            case (state)
                IDLE: begin
                    //nothing to act on, other than keep everything at default
                end

                FETCH_TYPE: begin
                    o_active = 1'b1;
                    //waiting for reg_file read, nothing.
                end

                LOAD_INIT: begin
                    o_active = 1'b1;
                    //waiting for reg_file read, nothing.
                end

                LOAD_PARAMS: begin
                    o_active = 1'b1;
                    o_block_en = type_onehot;
                    o_param_addr = 4'(param_idx);
                    o_param_data = i_regfile_data;   // data from previous cycle's read
                    o_param_wr_en   = 1'b1;
                end

                START_BLOCK: begin
                    o_active = 1'b1;
                    o_block_en = type_onehot;
                    o_block_start = type_onehot;
                    o_param_wr_en = 1'b0;
                    v_drive = active_block_drive[DAC_WIDTH-1:0];
                end

                WAIT_DONE: begin
                    o_active = 1'b1;
                    o_block_en = type_onehot;
                    v_drive = active_block_drive[DAC_WIDTH-1:0];
                end

                CAPTURE_VDRIVE: begin
                    o_active = 1'b1;
                    o_block_en = type_onehot;
                    v_drive = active_block_drive[DAC_WIDTH-1:0];
                end

                DONE: begin
                    //done with everything, flag done signal
                    o_seq_done = 1'b1;
                end

                default: begin
                    //lol
                end
            endcase
        end

endmodule
`default_nettype wire