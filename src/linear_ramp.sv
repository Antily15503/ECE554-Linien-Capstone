//Linear Ramp block; simple shi
////////////////// Parameters //////////////////
//NOTE: try to avoid any kind of division if possible. 
//0x00: v_start; starting drive voltage
//0x01: v_step; 

module linear_ramp (
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
  wire  [31:0] v_start;
  wire  [31:0] v_step;

  logic [31:0] params  [1:0];
  assign v_start = params[0];
  assign v_step  = params[1];

  always@(posedge clk)begin
    if(~rst_n)begin
      for (integer i=0;i<2;i=i+1)begin
        params[i]<=32'b0;
      end
    end else begin

    end
  end

endmodule



