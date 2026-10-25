`timescale 1ns / 1ps
`default_nettype none

import CORE_PKG::*;

module DP_SRAM (
  input   logic                     CLK_i,
  
  // Read port
  input   logic [PC_WIDTH - 1:0]    ADDR_RD_i,
  output  instr_t                   DATA_RD_o,
  
  // WRite
  input   logic                     WE_i,
  input   logic [INSTR_WIDTH - 1:0] ADDR_WR_i,
  input   logic [INSTR_WIDTH - 1:0] DATA_WR_i
);

wire [15:0] dout;

  RM_IHPSG13_2P_1024x16_c2_bm_bist sram_macro (
      .A_CLK(CLK_i),
      .A_MEN(WE_i),             // Enable Port A only when writing
      .A_WEN(WE_i),             // Write Enable
      .A_REN(1'b0),             // No reading on Port A
      .A_ADDR(ADDR_WR_i[9:0]),
      .A_DIN(DATA_WR_i),
      .A_DLY(1'b1),
      .A_DOUT(),                // Unconnected
      .A_BM(16'hFFFF),          // Enable all 16 bits
      .B_CLK(CLK_i),
      .B_MEN(1'b1),             // Port B always enabled for instruction fetch
      .B_WEN(1'b0),             // No writing on Port B
      .B_REN(1'b1),             // Always reading
      .B_ADDR(ADDR_RD_i[9:0]),
      .B_DIN(16'b0),            // Unconnected
      .B_DLY(1'b1),
      .B_DOUT(dout),
      .B_BM(16'hFFFF),          // Enable all 16 bits
      .A_BIST_CLK(1'b0),
      .A_BIST_EN(1'b0),
      .A_BIST_MEN(1'b0),
      .A_BIST_WEN(1'b0),
      .A_BIST_REN(1'b0),
      .A_BIST_ADDR(10'b0),
      .A_BIST_DIN(16'b0),
      .A_BIST_BM(16'b0),
      .B_BIST_CLK(1'b0),
      .B_BIST_EN(1'b0),
      .B_BIST_MEN(1'b0),
      .B_BIST_WEN(1'b0),
      .B_BIST_REN(1'b0),
      .B_BIST_ADDR(10'b0),
      .B_BIST_DIN(16'b0),
      .B_BIST_BM(16'b0)
  );

  // Write (combinational)
  assign DATA_RD_o = instr_t'(dout);
  
endmodule