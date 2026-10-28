`timescale 1ns / 1ps
`default_nettype none

module SMU (
  input   logic               CLK_i,
  input   logic               RESET_n_i,
  input   logic               SMU_CMD_EN_i,
  input   logic [3:0]         SMU_OP_i,
  input   logic [15:0]        SMU_DATA_i,
  output  logic [15:0]        SMU_DATA_o
);

  localparam logic [3:0] SMU_OP_CLR      = 4'b0000;
  localparam logic [3:0] SMU_OP_CRC16    = 4'b0001;
  localparam logic [3:0] SMU_OP_BITREV   = 4'b0010;
  localparam logic [3:0] SMU_OP_BYTESWAP = 4'b0011;
  localparam logic [3:0] SMU_OP_LFSR     = 4'b0100;
  localparam logic [3:0] SMU_OP_PARITY   = 4'b0101;
  localparam logic [3:0] SMU_OP_SETPOLY  = 4'b0110;
  localparam logic [3:0] SMU_OP_SETSEED  = 4'b0111;

  localparam logic [15:0] DEFAULT_POLY = 16'h6767;
  localparam logic [15:0] DEFAULT_SEED = 16'h6767;
  
  logic [15:0]  acc_reg;
  logic [15:0]  poly_reg;
  logic [15:0]  crc_next;
  logic [15:0]  bitrev_next;
  logic         lfsr_fb;
  
  integer i;

  always_comb begin
    for (i = 0; i < 16; i = i + 1) begin
      bitrev_next[i] = SMU_DATA_i[15 - i];
    end
    
    crc_next = acc_reg ^ SMU_DATA_i;
    for (i = 0; i < 16; i = i + 1) begin
      if (crc_next[15]) begin
        crc_next = (crc_next << 1) ^ poly_reg;
      end else begin
        crc_next = (crc_next << 1);
      end
    end
    
    lfsr_fb = ^(acc_reg & poly_reg);
  end
  
  always_ff @(posedge CLK_i or negedge RESET_n_i) begin
    if (!RESET_n_i) begin
      acc_reg   <= DEFAULT_SEED;
      poly_reg  <= DEFAULT_POLY;
    end else if (SMU_CMD_EN_i) begin
      case (SMU_OP_i) 
        SMU_OP_CLR      : acc_reg   <= '1;
        SMU_OP_CRC16    : acc_reg   <= crc_next;
        SMU_OP_BITREV   : acc_reg   <= bitrev_next;
        SMU_OP_BYTESWAP : acc_reg   <= {SMU_DATA_i[7:0], SMU_DATA_i[15:8]};
        SMU_OP_LFSR     : acc_reg   <= {acc_reg[14:0], lfsr_fb};
        SMU_OP_PARITY   : acc_reg   <= {15'b0, ^SMU_DATA_i};
        SMU_OP_SETPOLY  : poly_reg  <= SMU_DATA_i;
        SMU_OP_SETSEED  : acc_reg   <= SMU_DATA_i;
        default         : acc_reg   <= SMU_DATA_i;
      endcase
    end
  end
  
  assign SMU_DATA_o = acc_reg;
endmodule