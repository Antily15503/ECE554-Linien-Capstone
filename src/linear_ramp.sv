//Linear Ramp block; simple shi
////////////////// Parameters //////////////////
//NOTE: try to avoid any kind of division if possible. 
//0x00: v_start; starting drive voltage
//0x01: v_step; 

module linear_ramp #(
  parameter DATA_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,

    input logic en,
    input logic [DATA_WIDTH-1:0] i_param_data,
    input logic [3:0] i_param_addr,
    input logic i_active,

    output logic signed [13:0] v_drive
);

  //param 0: v_start
  //param 1: v_step
  logic [13:0] v_start;
  logic [13:0] v_step;
  
  always_ff @ (posedge clk) begin
    if (!rst_n) begin
      v_start <= '0;
      v_step <= '0;
    end else if (en) begin
      unique case (i_param_addr)
        4'd0: v_start <= i_param_data[13:0];
        4'd1: v_step <= i_param_data[13:0];
      endcase
    end
  end

  logic active_ff;
  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) active_ff <= 1'b0;
    else active_ff <= i_active;
  end

  logic active_ff_posedge;
  always @(posedge clk, negedge rst_n) begin
    if (rst_n) active_ff_posedge <= 1'b0;
    else begin
      active_ff_posedge <= (~active_ff && i_active);
    end
  end

  logic [13:0] o_drive_ff;

  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) o_drive_ff <= 14'b0;
    else begin
      if (active_ff_posedge) o_drive_ff <= v_start;
      else if (active_ff) begin
        o_drive_ff <= o_drive_ff + v_step;
      end
    end
  end
endmodule
