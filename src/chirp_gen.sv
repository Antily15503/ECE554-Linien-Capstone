`default_nettype none
//0x00 = this is the address for the parameter a
//0x01 = this is the address for the parameter b
//0x02 = this is the address for the parameter rate
//0x03 = this is the address for the parameter raterate

module chirp_gen (
    input wire clk,
    input wire rst_n,
    input wire [4:0] param_add,
    input wire [31:0] param_data,
    input wire  en, // this is the start signal
   

    output logic [14:0] voltage,
    output logic done
);



logic [23:0] cur_rate; // This will hold the current rate of change of the frequency.
logic [31:0] a; // This is the starting frequency.
logic [31:0] b; // This is the ending frequency.
logic [31:0] rate; // This is the initial rate of change of the frequency.
logic [31:0] raterate; // This is the rate of change of the rate of change of the frequency.

always_ff @(posedge clk) begin
    if (!rst_n) begin
        a <= '0;
        b <= '0;
        rate <= '0;
        raterate <= '0;
    end else if (en) begin
        unique case (param_add)
            4'd0: a <= param_data;
            4'd1: b <= param_data;
            4'd2: rate <= param_data;
            4'd3: raterate <= param_data;
        endcase 
    end
end

logic load_done;
integer i = 0;
  always_ff @(posedge clk, negedge rst) begin
    
    if(i <= 4) begin    
        params[i] <= param_data;
        i = i + 1;
    end
    
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

`default_nettype wire