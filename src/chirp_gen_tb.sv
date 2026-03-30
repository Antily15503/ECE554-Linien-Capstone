module chirp_gen_tb();

// Declare signals FIRST
logic clk;
logic rst;
logic [13:0] a;
logic [13:0] b;
logic [23:0] rate;
logic [23:0] raterate;
logic start;

logic voltage;
logic done;

// DUT instantiation AFTER declarations
chirp_gen idut( 
    .clk(clk),
    .rst(rst),
    .a(a),
    .b(b),
    .start(start),
    .rate(rate),
    .raterate(raterate),
    .voltage(voltage),
    .done(done)
);

// Stimulus
initial begin 
    clk = 0;
    rst = 1;
    a = 14'h001;
    b = 14'h100;
    rate = 24'd000;
    raterate = 24'h001;

    @(posedge clk);
    rst = 0;
    start = 1;

    #1000000;
    $finish;
end

// Clock generation
always #1 clk = ~clk;

endmodule