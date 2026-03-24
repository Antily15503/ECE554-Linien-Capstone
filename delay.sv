module delay_gen (
    input en,
    input [13:0] v_from,

    output [13:0] v_drive
);
    assign v_drive = (en) ? v_from : v_drive;
endmodule