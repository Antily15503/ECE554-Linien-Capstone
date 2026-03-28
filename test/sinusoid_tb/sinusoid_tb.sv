module sinusoid_tb ();

  logic [4:0] i_param_addr;
  logic [31:0] i_param_data;
  logic i_en;
  logic i_start;
  logic rst_n;
  logic i_wren;
  logic clk;

  logic o_done;
  logic [13:0] o_drive;

  initial begin
    $dumpfile("sinusoid_tb.vcd");
    $dumpvars(0, sinusoid_tb);
  end
  sinusoid iDUT (
      .i_param_addr(i_param_addr),
      .i_param_data(i_param_data),
      .i_en(i_en),
      .i_start(i_start),
      .rst_n(rst_n),
      .i_wren(i_wren),
      .clk(clk),
      .o_done(o_done),
      .o_drive(o_drive)
  );

endmodule
