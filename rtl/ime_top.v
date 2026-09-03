module ime_top (
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
  localparam [2:0] ST_FIRE    = 3'd2;
  localparam [2:0] ST_WAIT    = 3'd3;
  localparam [2:0] ST_DRAIN_C = 3'd4;

  reg [2:0]   state, state_n;
  reg [3:0]   beat;
  reg         acc_clr_r, do_load_r, do_drain_r;
  reg         done_r;
  reg [511:0] a_pack, b_pack;

  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_pack <= 512'h0;
      b_pack <= 512'h0;
    end else if (ab_we) begin
      for (i = 0; i < 16; i = i + 1) begin
        if (!ab_sel)
          a_pack[({ab_beat, 4'h0} + i[5:0]) * 8 +: 8] <= ab_data[i*8 +: 8];
        else
          b_pack[({ab_beat, 4'h0} + i[5:0]) * 8 +: 8] <= ab_data[i*8 +: 8];
      end
    end
  end

  wire mma_busy, mma_done;
  wire [127:0] arr_c_rd;
  wire load_fire  = (state == ST_LOAD_C)  & c_in_valid;
  wire drain_fire = (state == ST_DRAIN_C) & c_out_ready;
  wire mma_start  = (state == ST_FIRE);

  assign busy        = start | (state != ST_IDLE);
  assign done        = done_r;
  assign c_in_ready  = (state == ST_LOAD_C);
  assign c_out_valid = (state == ST_DRAIN_C);
  assign c_out_beat  = beat;
  assign c_out_data  = arr_c_rd;

  always @(*) begin
    state_n = state;
    case (state)
      ST_IDLE: begin
        if (start)
          state_n = do_load_c ? ST_LOAD_C : ST_FIRE;
      end
      ST_LOAD_C: begin
        if (load_fire && beat == 4'd15)
          state_n = ST_FIRE;
      end
      ST_FIRE:    state_n = ST_WAIT;
      ST_WAIT: begin
        if (mma_done)
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
      state      <= ST_IDLE;
      beat       <= 4'd0;
      acc_clr_r  <= 1'b0;
      do_load_r  <= 1'b0;
      do_drain_r <= 1'b0;
      done_r     <= 1'b0;
    end else begin
      state  <= state_n;
      done_r <= (state != ST_IDLE) && (state_n == ST_IDLE);

      if (state == ST_IDLE && start) begin
        acc_clr_r  <= acc_clr;
        do_load_r  <= do_load_c;
        do_drain_r <= do_drain_c;
        beat       <= 4'd0;
      end else if (state == ST_LOAD_C) begin
        if (load_fire)
          beat <= (beat == 4'd15) ? 4'd0 : (beat + 4'd1);
      end else if (state == ST_WAIT && mma_done) begin
        beat <= 4'd0;
      end else if (state == ST_DRAIN_C) begin
        if (drain_fire)
          beat <= beat + 4'd1;
      end
    end
  end

  mma_unit u_mma (
    .clk     (clk),
    .rst_n   (rst_n),
    .start   (mma_start),
    .acc_clr (acc_clr_r),
    .a_pack  (a_pack),
    .b_pack  (b_pack),
    .c_we    (load_fire),
    .c_beat  (beat),
    .c_wdata (c_in_data),
    .c_rdata (arr_c_rd),
    .busy    (mma_busy),
    .done    (mma_done)
  );

endmodule
