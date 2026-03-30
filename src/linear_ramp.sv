/*[Implementation Notes]
Start with reading in the enable signal, generate a one cycle pulse that represents rising edge of enable signal. This will be enable_pulse

enable_pulse high = first cycle the module is active. We will need to calculate the increment amount at this clock cycle with the divide module

==================== divide module ======================
ONLY ACTIVE IF enable_pulse is 1. 
When active, input flops go transparent to load in values to calculate. 

calculate the value (v_to - v_from) / duration , store into a global register within module (inc_amt), then increment v_drive by inc_amt.

On falling edge of enable_pulse, make input flops opaque to save power

==================== accumulator module ======================
ALWAYS ACTIVE WHILE MODULE IS ACTIVE.
At each clock cycle, increment v_drive by inc_amt, until module deasserts
*/


module linear_ramp (
    input clk,
    input rst_n,
    input en,
    input [13:0] v_from,
    input [13:0] v_to,

    output [13:0] v_drive
);
  //register for determining en_pulse from en signals
  wire en_ff, en_pulse;
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) en_ff <= '0;
    else en_ff <= en;
  end
  assign en_pulse = en && !en_ff;

  //comb block that calculates v_diff
  wire signed [13:0] v_diff;
  always_comb begin
    v_diff = $signed(v_to) - $signed(v_from);
  end


  //register complex for calculating accumulating addition for ramps
  wire signed [13:0] v_drive_reg;
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) v_drive_reg = '0;
    else if (en_pulse) v_drive_reg <= v_from;
    else v_drive_reg <= v_drive_reg + div_out;
  end
  assign v_drive = v_drive_reg;

endmodule



