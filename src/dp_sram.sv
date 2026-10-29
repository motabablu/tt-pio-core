`timescale 1ns / 1ps
`default_nettype none

module DP_SRAM (
  input   logic        CLK_i,
  input   logic [15:0] ADDR_RD_i,
  output  logic [15:0] DATA_RD_o,
  input   logic        WE_i,
  input   logic [15:0] ADDR_WR_i,
  input   logic [15:0] DATA_WR_i
);

//`ifndef SYNTHESIS
//  // Behavioral RAM for RTL Simulation
//  logic [15:0] mem [0:511];
//  always_ff @(posedge CLK_i) begin
//    if (WE_i) mem[ADDR_WR_i[8:0]] <= DATA_WR_i;
//    DATA_RD_o <= mem[ADDR_RD_i[8:0]];
//  end
//`else
  // Physical Macro for OpenLane Synthesis
  wire [15:0] dout;
  wire [15:0] unused_a_dout; // LVS ERRORS
  
  RM_IHPSG13_2P_512x16_c2_bm_bist sram (
      .A_CLK(CLK_i),
      .A_MEN(WE_i),
      .A_WEN(WE_i),
      .A_REN(1'b0),
      .A_ADDR(ADDR_WR_i[8:0]),
      .A_DIN(DATA_WR_i),
      .A_DLY(1'b1),
      .A_DOUT(unused_a_dout),
      .A_BM(16'hFFFF),
      .B_CLK(CLK_i),
      .B_MEN(1'b1),
      .B_WEN(1'b0),
      .B_REN(1'b1),
      .B_ADDR(ADDR_RD_i[8:0]),
      .B_DIN(16'b0),
      .B_DLY(1'b1),
      .B_DOUT(dout),
      .B_BM(16'hFFFF),
      .A_BIST_CLK(1'b0),
      .A_BIST_EN(1'b0),
      .A_BIST_MEN(1'b0),
      .A_BIST_WEN(1'b0),
      .A_BIST_REN(1'b0),
      .A_BIST_ADDR(9'b0),
      .A_BIST_DIN(16'b0),
      .A_BIST_BM(16'b0),
      .B_BIST_CLK(1'b0),
      .B_BIST_EN(1'b0),
      .B_BIST_MEN(1'b0),
      .B_BIST_WEN(1'b0),
      .B_BIST_REN(1'b0),
      .B_BIST_ADDR(9'b0),
      .B_BIST_DIN(16'b0),
      .B_BIST_BM(16'b0)
  );

  assign DATA_RD_o = dout;
//`endif

endmodule
