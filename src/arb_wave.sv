//0x00: clk_div: value for the clock divider
//into it
module arb_wave (
    input wire [4:0] i_param_addr,
    input wire [31:0] i_param_data,
    input wire i_en,
    input wire i_active,
    input wire rst_n,
    input wire clk,

    //BRAM ABSTRACTION
    output logic [ 9:0] o_bram_addr,
    input  wire  [13:0] i_bram_data,

    output logic signed [13:0] o_drive
);

  //param loading


  logic [DATA_WIDTH-1:0] clk_div;
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      clk_div <= 32'd1;  // default: step every cycle
    end else if (i_en && i_param_addr == 4'd0) begin
      clk_div <= i_param_data;
    end
  end

  logic active_ff;
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) active_ff <= 1'b0;
    else active_ff <= i_active;
  end

  logic active_ff;
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) active_ff <= 1'b0;
    else active_ff <= i_active;
  end
  logic active_pulse;
  assign active_pulse = i_active & ~active_ff;

  logic [DATA_WIDTH-1:0] div_counter;
  logic [9:0] bram_addr_r;

  always@(posedge clk, negedge rst_n)begin
  end


endmodule
