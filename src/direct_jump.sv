
module direct_jump #(
    parameter DATA_WIDTH = 32
) (
    input clk,
    input rst_n,

    input en,
    input active,

    input [DATA_WIDTH-1:0] i_param_data,
    input [           3:0] i_param_addr,

    output [13:0] v_drive
);
  //note: this module same as delay because the 1 clk cycle gap we have where we drive the pre-target voltage is handled by the FSM, not by this logic.
  logic [13:0] v_target;

  always_ff @(posedge clk) begin
    if (!rst_n) v_target <= '0;
    else if (en && i_param_addr == 4'd0) begin
      v_target <= i_param_data[13:0];
    end
  end

  assign v_drive = (active) ? v_target : '0;
endmodule

