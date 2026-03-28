module direct_jump (
    input clk,
    input rst_n,
    input en,
    input v_target,
    input [7:0] dur,

    output [13:0] v_drive
);
//note: this module same as delay because the 1 clk cycle gap we have where we drive the pre-target voltage is handled by the FSM, not by this logic.
    assign v_drive = (en) ? v_target : v_drive;
endmodule
