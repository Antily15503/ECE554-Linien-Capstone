//top level fsm, will get to later
`default_nettype none

/////////////////// Timer Module ///////////////////////
// Timer module. Takes in a threshold value (flopped), and enable.
// First, pulse enable. On enable pulse, make threshold flop transparent to read in new value, and reset counter. each clk cycle enable is on, increment count.
// When count == threshold, assert done.
// Then when en is 0, make flop opaque, stop everything.
////////////////////////////////////////////////////////
    module timer(
        input clk,
        input rst_n, 
        input en,
        input [7:0] threshold_in,

        output done
    )
        // flop to get en_pulse from en. SYNCRONOUS RESET
        wire en_ff, en_pulse;
        always_ff @ (posedge clk) begin
            if (!rst_n) en_ff <= '0;
            else en_ff <= en;
        end
        assign en_pulse = en && !en_ff;

        // flop to manage and lock threshold value. SYNCRONOUS RESET
        wire [7:0] threshold;
        always_ff @ (posedge clk) begin
            if (!rst_n) threshold <= '0;
            else begin
                if (en_pulse) threshold <= threshold_in;
            end else threshold <= threshold; //FIXME: don't know if this is necessary, might be redundant.
        end

        // incrementer+register to store and manage counter. SYNCRONOUS RESET
        reg [7:0] counter;
        always_ff @ (posedge clk) begin
            if (!en) counter <= '0;
            else begin
                counter <= counter + 1;
            end
        end

        assign done = (counter == threshold);
    endmodule

/////////////////// Control Module ///////////////////////
//Takes in 
// Timer module. Takes in a threshold value (flopped), and enable.
// First, pulse enable. On enable pulse, make threshold flop transparent to read in new value, and reset counter. each clk cycle enable is on, increment count.
// When count == threshold, assert done.
// Then when en is 0, make flop opaque, stop everything.
////////////////////////////////////////////////////////

/////////////////// FSM Module ///////////////////////
module fsm_top(
    input clk,
    input rst_n,
    input start,

    //TODO: input signals from instructions register
    input [38:0] instruction,

    output pc,
    output v_drive
);
    typedef enum [2:0] = {
        IDLE = 3'b100,
        TRANS = 3'b000,
        EXEC = 3'b001,
        JUMP = 3'b010
    } state_t;
    state_t state, next_state;

    //All wires and signals used for instructions + FSM
    wire [2:0] op;
    wire [7:0] dur;
    wire [13:0] v_from, v_to;

    always_comb begin
        //Initialize all control signals here 
        op <= '0;
        dur <= '0;
        v_from <= '0;
        v_to <= '0;
        next_state <= IDLE;


        unique case (state)
            IDLE:
                if (start) begin
                    //FSM start signal asserted: Start the FSM. TODO: Cement down how this works
                    next_state = TRANS;
                end else next_state = IDLE;
            TRANS:
                //TODO: FINISH TRANS
                //TODO: 1. finish parsing instructions, determine what module to turn on, get ready to start timer
                //TODO: if we hit the end of instruction, move to state IDLE.

            EXEC:
                //TODO: FINISH EXEC

                if (timer_done) begin
                    //FSM finish timer handler.
                    next_state = TRANS;
                end
            JUMP:
        endcase
    end

    // flip flop for next_state -> state
    always_ff @ (posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else state <= next_state;
    end
endmodule
`default_nettype wire