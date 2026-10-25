`timescale 1ns / 1ps
`default_nettype none

// Package
import CORE_PKG::*;

module REG_FILE(
  input logic     CLK_i,
  input logic     RESET_n_i,
   
  // Core
  input  logic                        WRITE_EN_i,
  input  logic [REG_ADDR_WIDTH - 1:0] WRITE_ADDR_i,
  input  logic [DATA_WIDTH - 1:0]     WRITE_DATA_i,
  input  logic [REG_ADDR_WIDTH - 1:0] READ_ADDR1_i,
  input  logic [REG_ADDR_WIDTH - 1:0] READ_ADDR2_i,
  output logic [DATA_WIDTH - 1:0]     READ_DATA1_o,
  output logic [DATA_WIDTH - 1:0]     READ_DATA2_o,
   
  // I/O
  input  logic [DATA_WIDTH - 1:0] PIN_IN_i,      // R12
  output logic [DATA_WIDTH - 1:0] PIN_OUT_o,     // R13
  output logic [DATA_WIDTH - 1:0] PIN_DIR_o,     // R14
   
  // SMU
  input  logic [DATA_WIDTH - 1:0] SMU_DATA_i,    // R15 (READ)
  output logic [DATA_WIDTH - 1:0] SMU_DATA_o     // R15 (WRITE)
);

  // General Purpose Registers
  logic [DATA_WIDTH - 1:0] gpr [0:GPR_COUNT - 1];
  
  integer i;
  
  
  // WRITE (SEQUENTIAL)
  always_ff @(posedge CLK_i or negedge RESET_n_i) begin
    if (!RESET_n_i) begin
      PIN_OUT_o   <= '0;
      PIN_DIR_o   <= '0;
      SMU_DATA_o  <= '0;
      for (i = 0; i < GPR_COUNT; i = i + 1) begin
        gpr[i] <= '0;
      end // i     
      
    end else if (WRITE_EN_i) begin
      // Address decoder
      case (WRITE_ADDR_i)
        PIN_IN_ADDR   : ;                                   // R12 is READ ONLY
        PIN_OUT_ADDR  : PIN_OUT_o         <= WRITE_DATA_i;
        PIN_DIR_ADDR  : PIN_DIR_o         <= WRITE_DATA_i;
        SMU_DATA_ADDR : SMU_DATA_o        <= WRITE_DATA_i;
        default       : gpr[WRITE_ADDR_i] <= WRITE_DATA_i;  // R0 - R11
      endcase // WRITE_ADDR_i
    end // RST_n_i, WRITE_EN_i
  end // always_ff, CLK_i, RESET_n_i
  
  
  // READ (COMBINATIONAL)
  always_comb begin
    // Port 1
    case (READ_ADDR1_i)
      PIN_IN_ADDR   : READ_DATA1_o = PIN_IN_i;
      PIN_OUT_ADDR  : READ_DATA1_o = PIN_OUT_o;         // Read back
      PIN_DIR_ADDR  : READ_DATA1_o = PIN_DIR_o;
      SMU_DATA_ADDR : READ_DATA1_o = SMU_DATA_i;
      default       : READ_DATA1_o = gpr[READ_ADDR1_i];
    endcase // READ_ADDR1_i
    
    // Port 2
    case (READ_ADDR2_i)
      PIN_IN_ADDR   : READ_DATA2_o  = PIN_IN_i;
      PIN_OUT_ADDR  : READ_DATA2_o  = PIN_OUT_o;        // Read back
      PIN_DIR_ADDR  : READ_DATA2_o  = PIN_DIR_o;
      SMU_DATA_ADDR : READ_DATA2_o  = SMU_DATA_i;
      default       : READ_DATA2_o = gpr[READ_ADDR2_i];
    endcase // READ_ADDR2_i
  end // always_comb

endmodule