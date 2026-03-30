//0x00 = this is the address for the parameter a
//0x01 = this is the address for the parameter b
//0x02 = this is the address for the parameter rate
//0x03 = this is the address for the parameter raterate

module chirp_gen (
    input logic clk,
    input logic rst,
    input logic [4:0] param_add,
    input logic [31:0] param_data,
    input logic  en, // this is the start signal
   

    output logic [14:0] voltage,
    output logic done
);


logic [23:0] cur_rate; // This will hold the current rate of change of the frequency.
logic [31:0] a; // This is the starting frequency.
logic [31:0] b; // This is the ending frequency.
logic [31:0] rate; // This is the initial rate of change of the frequency.
logic [31:0] raterate; // This is the rate of change of the rate of change of the frequency.

logic [31:0] params[5:0];

assign a = params[0];
assign b = params[1];
assign rate = params[2];
assign raterate = params[3];

logic load_done;

  always_ff @(posedge clk, negedge rst) begin
    
    params[i_param_add] <= i_param_data;
    i = i + 1;

    
    load_done = 'b1;

  end

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        voltage  <= a;        // START AT a
        cur_rate <= rate;
        done     <= 0;
    end else begin
        if (en && load_done) begin
        cur_rate <= cur_rate + raterate;
        voltage  <= voltage + cur_rate;

        if (a > b)
            done <= (voltage <= b); // DONE WHEN WE REACH b
        else
            done <= (voltage >= b); // DONE WHEN WE REACH b
        end
    end
end 

endmodule


        


 	