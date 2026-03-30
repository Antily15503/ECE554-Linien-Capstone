// assert rst with you want to start the chirp. 

module chirp_gen (
    input logic clk,
    input logic rst,
    input logic [13:0] a, // FROM GUI
    input logic [13:0] b, // FROM GUI
    input logic [23:0] rate, // calcualted on the processor stage. this is the initial rate of change of the frequency.
    input logic [23:0] raterate, // calcualted on the processor stage. This is the rate of change at which the rate of change changes.
    input logic  start, // this is the start signal
   

    output logic [14:0] voltage,
    output logic done
);

logic [23:0] cur_rate; // This will hold the current rate of change of the frequency.

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        voltage  <= a;        // START AT a
        cur_rate <= rate;
        done     <= 0;
    end else begin
        if (start) begin
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


        


