module arb_wave (
    input wire [4:0] i_param_addr,
    input wire [31:0] i_param_data,
    input wire i_en,
    input wire i_start,
    input wire rst_n,
    input wire i_wren,
    input wire clk,
    output wire o_done,
    output logic signed [13:0] o_drive
);

endmodule
