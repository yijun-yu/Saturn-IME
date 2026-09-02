module array_os #(
  parameter integer N = 8
) (
  input  wire        clk,
  input  wire        rst_n,

  input  wire [N*8-1:0] a_west,
  input  wire [N-1:0]   a_west_valid,
  input  wire [N*8-1:0] b_north,
  input  wire [N-1:0]   b_north_valid,

  input  wire        acc_clr,

  input  wire        c_we,
  input  wire [3:0]  c_beat,
  input  wire [127:0] c_wdata,
  output wire [127:0] c_rdata
);

  wire [7:0]  a_h       [0:N-1][0:N];
  wire        a_h_valid [0:N-1][0:N];
  wire [7:0]  b_v       [0:N][0:N-1];
  wire        b_v_valid [0:N][0:N-1];
  wire [31:0] acc_rd    [0:N-1][0:N-1];

  wire [2:0] beat_row  = c_beat[3:1];
  wire       beat_half = c_beat[0];

  genvar i, j;
  generate
    for (i = 0; i < N; i = i + 1) begin : ROW
      assign a_h[i][0]       = a_west[i*8 +: 8];
      assign a_h_valid[i][0] = a_west_valid[i];
    end
    for (j = 0; j < N; j = j + 1) begin : COL
      assign b_v[0][j]       = b_north[j*8 +: 8];
      assign b_v_valid[0][j] = b_north_valid[j];
    end

    for (i = 0; i < N; i = i + 1) begin : Y
      for (j = 0; j < N; j = j + 1) begin : X
        wire acc_ld_pe = c_we
                       & (beat_row == i[2:0])
                       & (beat_half == j[2]);
        wire [31:0] acc_wd_pe = c_wdata[(j[1:0]*32) +: 32];

        pe_os u_pe (
          .clk         (clk),
          .rst_n       (rst_n),
          .a_in        (a_h[i][j]),
          .a_valid_in  (a_h_valid[i][j]),
          .a_out       (a_h[i][j+1]),
          .a_valid_out (a_h_valid[i][j+1]),
          .b_in        (b_v[i][j]),
          .b_valid_in  (b_v_valid[i][j]),
          .b_out       (b_v[i+1][j]),
          .b_valid_out (b_v_valid[i+1][j]),
          .acc_clr     (acc_clr),
          .acc_ld      (acc_ld_pe),
          .acc_wdata   (acc_wd_pe),
          .acc_rdata   (acc_rd[i][j])
        );
      end
    end
  endgenerate

  assign c_rdata = {
    acc_rd[beat_row][{beat_half, 2'b11}],
    acc_rd[beat_row][{beat_half, 2'b10}],
    acc_rd[beat_row][{beat_half, 2'b01}],
    acc_rd[beat_row][{beat_half, 2'b00}]
  };

endmodule
