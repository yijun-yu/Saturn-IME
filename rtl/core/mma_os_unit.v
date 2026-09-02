module mma_unit (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        start,
  input  wire        acc_clr,
  input  wire        do_load_c,
  input  wire        do_drain_c,

  input  wire        ab_we,
  input  wire        ab_sel,
  input  wire [1:0]  ab_beat,
  input  wire [127:0] ab_data,

  output wire        c_in_ready,
  input  wire        c_in_valid,
  input  wire [127:0] c_in_data,

  output wire        c_out_valid,
  input  wire        c_out_ready,
  output wire [127:0] c_out_data,
  output wire [3:0]  c_out_beat,

  output wire        busy,
  output wire        done
);

  localparam [2:0] ST_IDLE    = 3'd0;
  localparam [2:0] ST_LOAD_C  = 3'd1;
  localparam [2:0] ST_CLR     = 3'd2;
  localparam [2:0] ST_COMPUTE = 3'd3;
  localparam [2:0] ST_DRAIN_C = 3'd4;

  localparam integer T_LAST = 21;

  reg [2:0]  state, state_n;
  reg [4:0]  t;
  reg [3:0]  beat;
  reg        clr_pending;
  reg        do_drain_r;
  reg        done_r;

  reg [7:0] a_tile [0:63];
  reg [7:0] b_tile [0:63];

  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (k = 0; k < 64; k = k + 1) begin
        a_tile[k] <= 8'h00;
        b_tile[k] <= 8'h00;
      end
    end else if (ab_we) begin
      if (!ab_sel) begin
        a_tile[{ab_beat, 4'd0}]  <= ab_data[  7:  0];
        a_tile[{ab_beat, 4'd1}]  <= ab_data[ 15:  8];
        a_tile[{ab_beat, 4'd2}]  <= ab_data[ 23: 16];
        a_tile[{ab_beat, 4'd3}]  <= ab_data[ 31: 24];
        a_tile[{ab_beat, 4'd4}]  <= ab_data[ 39: 32];
        a_tile[{ab_beat, 4'd5}]  <= ab_data[ 47: 40];
        a_tile[{ab_beat, 4'd6}]  <= ab_data[ 55: 48];
        a_tile[{ab_beat, 4'd7}]  <= ab_data[ 63: 56];
        a_tile[{ab_beat, 4'd8}]  <= ab_data[ 71: 64];
        a_tile[{ab_beat, 4'd9}]  <= ab_data[ 79: 72];
        a_tile[{ab_beat, 4'd10}] <= ab_data[ 87: 80];
        a_tile[{ab_beat, 4'd11}] <= ab_data[ 95: 88];
        a_tile[{ab_beat, 4'd12}] <= ab_data[103: 96];
        a_tile[{ab_beat, 4'd13}] <= ab_data[111:104];
        a_tile[{ab_beat, 4'd14}] <= ab_data[119:112];
        a_tile[{ab_beat, 4'd15}] <= ab_data[127:120];
      end else begin
        b_tile[{ab_beat, 4'd0}]  <= ab_data[  7:  0];
        b_tile[{ab_beat, 4'd1}]  <= ab_data[ 15:  8];
        b_tile[{ab_beat, 4'd2}]  <= ab_data[ 23: 16];
        b_tile[{ab_beat, 4'd3}]  <= ab_data[ 31: 24];
        b_tile[{ab_beat, 4'd4}]  <= ab_data[ 39: 32];
        b_tile[{ab_beat, 4'd5}]  <= ab_data[ 47: 40];
        b_tile[{ab_beat, 4'd6}]  <= ab_data[ 55: 48];
        b_tile[{ab_beat, 4'd7}]  <= ab_data[ 63: 56];
        b_tile[{ab_beat, 4'd8}]  <= ab_data[ 71: 64];
        b_tile[{ab_beat, 4'd9}]  <= ab_data[ 79: 72];
        b_tile[{ab_beat, 4'd10}] <= ab_data[ 87: 80];
        b_tile[{ab_beat, 4'd11}] <= ab_data[ 95: 88];
        b_tile[{ab_beat, 4'd12}] <= ab_data[103: 96];
        b_tile[{ab_beat, 4'd13}] <= ab_data[111:104];
        b_tile[{ab_beat, 4'd14}] <= ab_data[119:112];
        b_tile[{ab_beat, 4'd15}] <= ab_data[127:120];
      end
    end
  end

  assign busy = start | (state != ST_IDLE);
  assign done = done_r;

  wire load_fire  = (state == ST_LOAD_C)  & c_in_valid;
  wire drain_fire = (state == ST_DRAIN_C) & c_out_ready;

  assign c_in_ready  = (state == ST_LOAD_C);
  assign c_out_valid = (state == ST_DRAIN_C);
  assign c_out_beat  = beat;

  always @(*) begin
    state_n = state;
    case (state)
      ST_IDLE: begin
        if (start) begin
          if (do_load_c)       state_n = ST_LOAD_C;
          else if (acc_clr)    state_n = ST_CLR;
          else                 state_n = ST_COMPUTE;
        end
      end
      ST_LOAD_C: begin
        if (load_fire && beat == 4'd15)
          state_n = clr_pending ? ST_CLR : ST_COMPUTE;
      end
      ST_CLR:     state_n = ST_COMPUTE;
      ST_COMPUTE: begin
        if (t == T_LAST[4:0])
          state_n = do_drain_r ? ST_DRAIN_C : ST_IDLE;
      end
      ST_DRAIN_C: begin
        if (drain_fire && beat == 4'd15)
          state_n = ST_IDLE;
      end
      default: state_n = ST_IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= ST_IDLE;
      t           <= 5'd0;
      beat        <= 4'd0;
      clr_pending <= 1'b0;
      do_drain_r  <= 1'b0;
      done_r      <= 1'b0;
    end else begin
      state  <= state_n;
      done_r <= (state != ST_IDLE) && (state_n == ST_IDLE);

      if (state == ST_IDLE && start) begin
        clr_pending <= acc_clr;
        do_drain_r  <= do_drain_c;
        t           <= 5'd0;
        beat        <= 4'd0;
      end else if (state == ST_LOAD_C) begin
        if (load_fire) beat <= beat + 4'd1;
      end else if (state == ST_CLR) begin
        clr_pending <= 1'b0;
        t           <= 5'd0;
      end else if (state == ST_COMPUTE) begin
        if (t == T_LAST[4:0]) beat <= 4'd0;
        else                  t    <= t + 5'd1;
      end else if (state == ST_DRAIN_C) begin
        if (drain_fire) beat <= beat + 4'd1;
      end
    end
  end

  wire acc_clr_pe = (state == ST_CLR);

  reg [63:0] a_west;
  reg [7:0]  a_west_valid;
  reg [63:0] b_north;
  reg [7:0]  b_north_valid;

  integer r, c;
  always @(*) begin
    a_west = 64'h0; a_west_valid = 8'h0;
    b_north = 64'h0; b_north_valid = 8'h0;
    if (state == ST_COMPUTE) begin
      for (r = 0; r < 8; r = r + 1) begin
        if (t >= r[4:0] && (t - r[4:0]) < 5'd8) begin
          a_west_valid[r]  = 1'b1;
          a_west[r*8 +: 8] = a_tile[r*8 + (t - r[4:0])];
        end
      end
      for (c = 0; c < 8; c = c + 1) begin
        if (t >= c[4:0] && (t - c[4:0]) < 5'd8) begin
          b_north_valid[c]  = 1'b1;
          b_north[c*8 +: 8] = b_tile[(t - c[4:0])*8 + c];
        end
      end
    end
  end

  wire [127:0] arr_c_rd;
  assign c_out_data = arr_c_rd;

  array_os #(.N(8)) u_array (
    .clk           (clk),
    .rst_n         (rst_n),
    .a_west        (a_west),
    .a_west_valid  (a_west_valid),
    .b_north       (b_north),
    .b_north_valid (b_north_valid),
    .acc_clr       (acc_clr_pe),
    .c_we          (load_fire),
    .c_beat        (beat),
    .c_wdata       (c_in_data),
    .c_rdata       (arr_c_rd)
  );

endmodule
