module delay_gen (
    input clk,
    input rst_n
    input en,
    input [13:0] v_from,
    input [13:0] v_to,
    input [7:0] dur,

    output [13:0] v_drive
);
    //register for determining en_pulse
    wire en_ff, en_pulse;
    always_ff @ (posedge clk, negedge rst_n) begin
        if (!rst_n) en_ff <= '0;
        else en_ff <= en;
    end
    assign en_pulse = en && !en_ff;

    //comb block that calculates the v diff
    wire signed [13:0] v_diff
    always_comb begin
        v_diff = $signed(v_to) - $signed(v_from);
    end

    reg [13:0] div_out;
    //register complex for calculating division
    always_ff @ (posedge clk, negedge rst_n) begin
        if (!rst_n) div_out <= '0;
        else if (en_pulse) begin
            div_out <= v_diff/dur;
        end
    end

    //register complex for calculating accumulating addition for ramps
    wire signed [13:0] v_drive_reg;
    always_ff @ (posedge clk, negedge rst_n) begin
        if (!rst_n) v_drive_reg = '0
        else if (en_pulse) v_drive_reg <= v_from;
        else v_drive_reg <= v_drive_reg += div_out;
    end
    assign v_drive = v_drive_reg;

endmodule