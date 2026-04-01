module chirp_gen_tb();

// Declare signals FIRST
logic clk;
logic rst;
logic [4:0] param_add;
logic [31:0] param_data;
logic [4:0] i_param_add;
logic [31:0] i_param_data;
logic start;

logic [13:0] voltage;
logic done;

// DUT instantiation AFTER declarations
chirp_gen idut( 
    .clk(clk),
    .rst_n(rst),
    .i_param_add(i_param_add),
    .i_param_data(i_param_data),
    .en(start),

    .voltage(voltage),
    .done(done)
);


// Stimulus
initial begin 
    clk = 0;
    start = 1;
    @(posedge clk);
    i_param_add = 4'd0;
    i_param_data = 32'h00000000;
    @(posedge clk);
    i_param_add = 4'd1;
    i_param_data = 32'h00001000;
    @(posedge clk);
    i_param_add = 4'd2;
    i_param_data = 32'h00000000;
    @(posedge clk);
    i_param_add = 4'd3;
    i_param_data = 32'hFFFFFFFF;

    @(posedge clk);
    rst = 1;
    @(posedge clk);
    
    start = 1;
    rst = 0;
    @(posedge clk);

    #100000; // wait for some time to observe the output

$finish;


end

// Clock generation
always #1 clk = ~clk;

endmodule