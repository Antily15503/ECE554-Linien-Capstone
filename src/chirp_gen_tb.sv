module chirp_gen_tb();

// Declare signals FIRST
logic clk;
logic rst;
logic [4:0] param_add;
logic [31:0] param_data;
logic [4:0] i_param_add;
logic [31:0] i_param_data;
logic start;

logic voltage;
logic done;

// DUT instantiation AFTER declarations
chirp_gen idut( 
    .clk(clk),
    .rst(rst),
    .param_add(i_param_add),
    .param_data(i_param_data),
    .en(start),

    .voltage(voltage),
    .done(done)
);


// Stimulus
initial begin 
    clk = 0;
    i_param_add = 0;
    i_param_data = 32'h0000;
    @(posedge clk);
    i_param_add = 1;
    i_param_data = 32'h1000;
    @(posedge clk);
    i_param_add = 2;
    i_param_data = 32'h0000;
    @(posedge clk);
    i_param_add = 3;
    i_param_data = 32'h0001;

    @(posedge clk);
    start = 1;
    rst = 1;
    @(posedge clk);
    
    rst = 0;
    @(posedge clk);

    #100000; // wait for some time to observe the output

$finish;


end

// Clock generation
always #1 clk = ~clk;

endmodule