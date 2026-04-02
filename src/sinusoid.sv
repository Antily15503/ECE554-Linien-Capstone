//Sinusoid generator; simple block, for testing generation and simulation of
//waveforms?
////////////////// Parameters //////////////////
//0x00:v_mid; middle value (i.e, DC offset)
//0x01:v_amp; amplitude of sinusoid
//0x02: v_min_cutoff; minimum cutoff voltge
//0x03: v_max_cutoff; maximum cutoff voltge
//0x04: phase_increment; phase_increment for the sin generator; indexes into
//14x1024 LUT for values. 
//0x05: time; timer, or how long the block should execute for. 

module sinusoid #(
    parameter DATA_WIDTH
  )(
    input wire [4:0] i_param_addr,
    input wire [31:0] i_param_data,
    input wire i_en,
    input wire i_start,
    input wire rst_n,
    input wire clk,

    output wire o_done,
    output logic signed [13:0] o_drive
);

  wire [31:0] v_mid;
  wire [31:0] v_amp;
  wire [31:0] v_min_cut;
  wire [31:0] v_max_cut;
  wire [31:0] phase_increment;
  wire [31:0] run_time;

  logic [31:0] params[5:0];

  assign v_mid = params[0];
  assign v_amp = params[1];
  assign v_min_cut = params[2];
  assign v_max_cut = params[3];
  assign phase_increment = params[4];
  assign run_time = params[5];
  logic [1:0] curr_state, next_state;
  localparam IDLE = 2'b00;
  localparam WORK = 2'b01;

  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      for (integer i = 0; i < 6; i = i + 1) begin
        params[i] <= 32'b0;
      end
    end else begin
      //if this block is enabled and i_wren is high, load in the value
      if (i_en) begin

        //if the param address is within the range of parameters, load it in
        //AND if the current state is IDLE; dont allow writes while working
        if (i_param_addr <= 5'h5 && curr_state == IDLE) begin
          params[i_param_addr] <= i_param_data;
        end  //otherwise, ignore
        else begin
        end
      end
    end
  end

  // logicisters to keep track of current driving voltage and current phase

  //////////////////// THEORY: Numerically contlle oscillators and phase accumulators ////////////////////
  //sin wave is simply sim(phi), where phi is the phase, between 0 and 2*pi
  //repeatedly. 
  //a sin wave of frequency f implies that the phase phi increases by 2*pi*f
  //(or 2*pi/t,t=1/f) radians per second. 
  //at every clock cycle, the phase should increase by 2*pi*f*T_clk
  //
  //2*pi cant be stored in logicisters, so map 0->2*pi to the full range of an
  //N bit integer, 0->2^N. Phase accumulator is in "integer phase units"
  //for a 32 bit accumulator, a full circle is 2^32
  //hence phase increment becomes (f_desired/f_clk)*2^32
  //possibly add other LUT's to work with? 

  logic [31:0] phase_accum;
  logic signed [13:0] sin_LUT[1023:0];
  initial begin
    $readmemh("sin_lut.memh", sin_LUT);
  end


  logic start_ff;
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) start_ff <= 1'b0;
    else start_ff <= i_start;
  end

  logic start_pulse;
  assign start_pulse = i_start & ~start_ff;

  always_comb begin
    case (curr_state)
      //if currently idle and start_pulse, go to work
      2'b00: begin
        if (start_pulse) next_state = 2'b01;
        else next_state = 2'b00;
      end
      2'b01: begin
        if (o_done) next_state = 2'b00;
        else next_state = 2'b01;
      end
    endcase
  end

  //o_done should be asserted once the timer reaches the time parameter
  logic [31:0] timer;
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) timer <= 32'b0;
    else begin
      if (curr_state == WORK) begin
        timer <= timer + 1;
      end else if (curr_state == IDLE) begin
        timer <= 32'b0;
      end
    end
  end

  //o_done will be a pulse(?)
  assign o_done = (timer == run_time) && (curr_state == WORK);

  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) curr_state <= 2'b00;
    else curr_state <= next_state;
  end

  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) phase_accum <= 32'b0;
    else begin
      if (curr_state == WORK) begin
        phase_accum <= phase_accum + phase_increment;
      end  //while in the idle state, reset back to 0; dont maintain previous phase?
      else if (curr_state == IDLE) begin
        phase_accum <= 32'b0;
      end
    end
  end

  //Note: sin_LUT stores signed values of sin, from -2^13 to 2^13, 
  //representing -1 to 1 normalized. 
  //v_amp scales it, v_mid shifts it. 
  logic signed [13:0] lut_raw;
  logic signed [31:0] raw_out;
  wire signed  [31:0] v_mid_s = $signed(v_mid);
  wire signed  [31:0] v_amp_s = $signed(v_amp);
  wire signed  [31:0] v_min_cut_s = $signed(v_min_cut);
  wire signed  [31:0] v_max_cut_s = $signed(v_max_cut);

  always_comb begin
    lut_raw = sin_LUT[phase_accum[31:22]];
    raw_out = v_mid_s + ((lut_raw * v_amp_s) >> 13);
    o_drive = (raw_out > v_max_cut_s) ? v_max_cut_s : (raw_out < v_min_cut_s) ? v_min_cut_s : raw_out[13:0];
  end

endmodule

