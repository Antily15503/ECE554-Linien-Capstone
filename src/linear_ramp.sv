//Linear Ramp block; simple shi
////////////////// Parameters //////////////////
//NOTE: try to avoid any kind of division if possible. 
//0x00: v_start; starting drive voltage
//0x01: v_step; 

module linear_ramp (
    input wire [3:0] i_param_addr,
    input wire [31:0] i_param_data,
    input wire i_en,
    input wire i_active,
    input wire rst_n,
    input wire i_wren,
    input wire clk,

    output logic signed [13:0] o_drive
);

  logic [31:0] params[1:0];
  assign v_start = params[0];
  assign v_step  = params[1];

  always @(posedge clk) begin
    if (~rst_n) begin
      for (integer i = 0; i < 2; i = i + 1) begin
        params[i] <= 32'b0;
      end
    end else begin
      if (i_en && i_wren) begin
        if (i_param_addr <= 5'h01) begin
          params[i_param_addr] <= i_param_data;
        end else begin
        end
      end
    end
  end

  logic active_ff;
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) active_ff <= 1'b0;
    else active_ff <= i_active;
  end

  logic active_ff_posedge;
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) active_ff_posedge <= 1'b0;
    else begin
      active_ff_posedge <= (~active_ff && i_active);
    end
  end

  logic [13:0] o_drive_ff;
  assign o_drive = o_drive_ff;

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
