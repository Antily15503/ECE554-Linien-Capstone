`default_nettype none
//0x00 = this is the address for the parameter a
//0x01 = this is the address for the parameter b
//0x02 = this is the address for the parameter rate
//0x03 = this is the address for the parameter raterate

module chirp_gen (
    input wire clk,
    input wire rst_n,
    input wire [4:0] i_param_add,
    input wire [31:0] i_param_data,
    input wire  en, // this is the start signal
   

    output logic [13:0] voltage,
    output logic done
);



logic signed [31:0] cur_rate; // This will hold the current rate of change of the frequency.
logic signed [31:0] a; // This is the starting frequency.
logic signed [31:0] b; // This is the ending frequency.
logic signed [31:0] rate; // This is the initial rate of change of the frequency.
logic signed [31:0] raterate; // This is the rate of change of the rate of change of the frequency.

always_ff @(posedge clk) begin
    /*if (!rst_n) begin
        a <= '0;
        b <= '0;
        rate <= '0;
        raterate <= '0;
    end  */ // this reset was messing up my following code so their is not re
    
    if (en) begin
        unique case (i_param_add)
            4'd0: a <= i_param_data;
            4'd1: b <= i_param_data;
            4'd2: rate <= i_param_data;
            4'd3: raterate <= i_param_data;
        endcase 
    end
end


always_ff @(posedge clk or posedge rst_n) begin
    if (rst_n) begin
        voltage  <= a;        // START AT a
        cur_rate <= rate;
        done     <= 0;
    end else begin
        if (en) begin
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

`default_nettype wire