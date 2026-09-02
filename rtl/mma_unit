module mma_unit #(
  parameter N = 8
) (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        start,
  input  wire        acc_clr,
  input  wire signed [7:0] A [0:N*N-1],
  input  wire signed [7:0] B [0:N*N-1],
  output wire        busy,
  output wire        done,
  output wire signed [31:0] acc [0:N-1][0:N-1]
);
  localparam LAST = 3 * N - 3;

  reg        busy_r;
  reg  [5:0] t;
  wire [5:0] t_eff = start ? 6'd0 : t;
  wire       en    = start | busy_r;

  integer ii, jj;
  reg        a_valid_in [0:N-1];
  reg signed [7:0] a_in [0:N-1];
  reg        b_valid_in [0:N-1];
  reg signed [7:0] b_in [0:N-1];

  always @(*) begin
    for (ii = 0; ii < N; ii = ii + 1) begin
      if (en && (t_eff >= ii) && ((t_eff - ii) < N)) begin
        a_valid_in[ii] = 1'b1;
        a_in[ii] = A[ii*N + (t_eff - ii)];
      end else begin
        a_valid_in[ii] = 1'b0;
        a_in[ii] = 8'sd0;
      end
    end
    for (jj = 0; jj < N; jj = jj + 1) begin
      if (en && (t_eff >= jj) && ((t_eff - jj) < N)) begin
        b_valid_in[jj] = 1'b1;
        b_in[jj] = B[(t_eff - jj)*N + jj];
      end else begin
        b_valid_in[jj] = 1'b0;
        b_in[jj] = 8'sd0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy_r <= 1'b0;
      t      <= 6'd0;
    end else if (start) begin
      busy_r <= 1'b1;
      t      <= 6'd1;
    end else if (busy_r) begin
      if (t == LAST[5:0]) busy_r <= 1'b0;
      else t <= t + 6'd1;
    end
  end

  assign busy = start | busy_r;

  reg done_r;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) done_r <= 1'b0;
    else done_r <= busy_r && (t == LAST[5:0]);
  end
  assign done = done_r;

  array_os #(.N(N)) u_arr (
    .clk(clk), .rst_n(rst_n), .en(en), .acc_clr(acc_clr),
    .a_valid_in(a_valid_in), .a_in(a_in),
    .b_valid_in(b_valid_in), .b_in(b_in),
    .acc(acc)
  );
endmodule
