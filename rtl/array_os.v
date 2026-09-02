module array_os #(
  parameter N = 8
) (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        en,
  input  wire        acc_clr,
  input  wire        a_valid_in [0:N-1],
  input  wire signed [7:0] a_in [0:N-1],
  input  wire        b_valid_in [0:N-1],
  input  wire signed [7:0] b_in [0:N-1],
  output wire signed [31:0] acc [0:N-1][0:N-1]
);
  wire        av[0:N-1][0:N-1];
  wire signed [7:0] ah[0:N-1][0:N-1];
  wire        bv[0:N-1][0:N-1];
  wire signed [7:0] bh[0:N-1][0:N-1];

  genvar i, j;
  generate
    for (i = 0; i < N; i = i + 1) begin : ROW
      for (j = 0; j < N; j = j + 1) begin : COL
        pe_os pe (
          .clk(clk), .rst_n(rst_n), .en(en), .acc_clr(acc_clr),
          .a_valid_in(j == 0 ? a_valid_in[i] : av[i][j-1]),
          .a_in      (j == 0 ? a_in[i]       : ah[i][j-1]),
          .b_valid_in(i == 0 ? b_valid_in[j] : bv[i-1][j]),
          .b_in      (i == 0 ? b_in[j]       : bh[i-1][j]),
          .a_valid_out(av[i][j]),
          .a_out      (ah[i][j]),
          .b_valid_out(bv[i][j]),
          .b_out      (bh[i][j]),
          .acc        (acc[i][j])
        );
      end
    end
  endgenerate
endmodule
