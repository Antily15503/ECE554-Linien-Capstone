//0x00: clk_div: value for the clock divider
//0x01: start_load: once written to, iteratively steps over LUT to load value
//into it
module arb_wave (
    input wire [4:0] i_param_addr,
    input wire [31:0] i_param_data,
    input wire i_en,
    input wire i_active,
    input wire rst_n,
    input wire clk,
    output logic signed [13:0] o_drive
);

  logic [31:0] params[1:0];
  logic [13:0] lut[1023:0];

  assign clk_div = params[0];
  assign start_load = params[1];

  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      for (integer i = 0; i < 2; i = i + 1) params[i] <= 32'b0;
    end else begin
      if (i_en && i_param_addr <= 5'h01) params[i_param_addr] <= i_param_data;
    end
  end

  logic active_ff;
  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) active_ff <= 1'b0;
    else active_ff <= i_active;
  end

  logic active_ff_posedge;
  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) active_ff_posedge <= 1'b0;
    else begin
      active_ff_posedge <= (~active_ff && i_active);
    end
  end

  //IMPORTANT: AFTER 0x01 HAS BEEN WRITTEN TO, GO INTO A STATE OF SEQUENTIALLY
  //READING I_PARAM_DATA VALUES INTO THE LUT
  localparam IDLE = 1'b0, READING = 1'b1;
  logic curr_state, next_state;
  //counter to keep track of which index is being written to in the LUT
  logic [9:0] counter;

  always_comb begin
    case (curr_state)
      IDLE: begin
      end
      READING: begin
      end
    endcase
  end

endmodule

