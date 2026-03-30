module delay (
  parameter DATA_WIDTH = 32
)(
    input en,
    input [13:0]           v_from,
    input [DATA_WIDTH-1:0] param_data,
    input [3:0]            param_addr,

    output [13:0] v_drive
);
  // info about parameters:
  //     param 1: first 13 bits = v_from
  //     param 2: 

  assign v_drive = (en) ? v_from : '0;
endmodule
