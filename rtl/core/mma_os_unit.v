module mma_unit (
  input  wire         clk,
  input  wire         rst_n,

  input  wire         start,
  input  wire         acc_clr,
  input  wire [511:0] a_pack,
  input  wire [511:0] b_pack,

  input  wire         c_we,
  input  wire [3:0]   c_beat,
  input  wire [127:0] c_wdata,
  output wire [127:0] c_rdata,

  output wire         busy,
  output wire         done
);

  localparam [1:0] ST_IDLE    = 2'd0;
  localparam [1:0] ST_CLR     = 2'd1;
  localparam [1:0] ST_COMPUTE = 2'd2;
  localparam integer T_LAST   = 21;

  reg [1:0]  state, state_n;
  reg [4:0]  t;
  reg        done_r;
  reg [7:0]  a_tile [0:63];
  reg [7:0]  b_tile [0:63];

  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (k = 0; k < 64; k = k + 1) begin
        a_tile[k] <= 8'h00;
        b_tile[k] <= 8'h00;
      end
    end else if (state == ST_IDLE && start) begin
      for (k = 0; k < 64; k = k + 1) begin
        a_tile[k] <= a_pack[k*8 +: 8];
        b_tile[k] <= b_pack[k*8 +: 8];
      end
    end
  end

  assign busy = start | (state != ST_IDLE);
  assign done = done_r;

  always @(*) begin
    state_n = state;
    case (state)
      ST_IDLE: begin
        if (start)
          state_n = acc_clr ? ST_CLR : ST_COMPUTE;
      end
      ST_CLR:     state_n = ST_COMPUTE;
      ST_COMPUTE: if (t == T_LAST[4:0]) state_n = ST_IDLE;
      default:    state_n = ST_IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= ST_IDLE;
      t      <= 5'd0;
      done_r <= 1'b0;
    end else begin
      state  <= state_n;
      done_r <= (state != ST_IDLE) && (state_n == ST_IDLE);
      if (state == ST_IDLE && start)
        t <= 5'd0;
      else if (state == ST_CLR)
        t <= 5'd0;
      else if (state == ST_COMPUTE && t != T_LAST[4:0])
        t <= t + 5'd1;
    end
  end

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

  array_os #(.N(8)) u_array (
    .clk           (clk),
    .rst_n         (rst_n),
    .a_west        (a_west),
    .a_west_valid  (a_west_valid),
    .b_north       (b_north),
    .b_north_valid (b_north_valid),
    .acc_clr       (state == ST_CLR),
    .c_we          (c_we),
    .c_beat        (c_beat),
    .c_wdata       (c_wdata),
    .c_rdata       (c_rdata)
  );

endmodule
