`timescale 1ns / 1ps
`default_nettype none

module REG_FILE(
  input  logic        CLK_i,
  input  logic        RESET_n_i,
  input  logic        WRITE_EN_i,
  input  logic [3:0]  WRITE_ADDR_i,
  input  logic [15:0] WRITE_DATA_i,
  input  logic [3:0]  READ_ADDR1_i,
  input  logic [3:0]  READ_ADDR2_i,
  output logic [15:0] READ_DATA1_o,
  output logic [15:0] READ_DATA2_o,
  input  logic [15:0] PIN_IN_i,
  output logic [15:0] PIN_OUT_o,
  output logic [15:0] PIN_DIR_o,
  input  logic [15:0] SMU_DATA_i,
  output logic [15:0] SMU_DATA_o
);

  import CORE_PKG::*;

  logic [15:0] gpr [0:11];
  integer i;
  
  always_ff @(posedge CLK_i or negedge RESET_n_i) begin
    if (!RESET_n_i) begin
      PIN_OUT_o   <= '0;
      PIN_DIR_o   <= '0;
      SMU_DATA_o  <= '0;
      for (i = 0; i < 12; i = i + 1) begin
        gpr[i] <= '0;
      end
    end else if (WRITE_EN_i) begin
      case (WRITE_ADDR_i)
        PIN_IN_ADDR   : ;
        PIN_OUT_ADDR  : PIN_OUT_o         <= WRITE_DATA_i;
        PIN_DIR_ADDR  : PIN_DIR_o         <= WRITE_DATA_i;
        SMU_DATA_ADDR : SMU_DATA_o        <= WRITE_DATA_i;
        default       : gpr[WRITE_ADDR_i] <= WRITE_DATA_i;
      endcase
    end
  end
  
  always_comb begin
    case (READ_ADDR1_i)
      PIN_IN_ADDR   : READ_DATA1_o = PIN_IN_i;
      PIN_OUT_ADDR  : READ_DATA1_o = PIN_OUT_o;
      PIN_DIR_ADDR  : READ_DATA1_o = PIN_DIR_o;
      SMU_DATA_ADDR : READ_DATA1_o = SMU_DATA_i;
      default       : READ_DATA1_o = gpr[READ_ADDR1_i];
    endcase
    
    case (READ_ADDR2_i)
      PIN_IN_ADDR   : READ_DATA2_o = PIN_IN_i;
      PIN_OUT_ADDR  : READ_DATA2_o = PIN_OUT_o;
      PIN_DIR_ADDR  : READ_DATA2_o = PIN_DIR_o;
      SMU_DATA_ADDR : READ_DATA2_o = SMU_DATA_i;
      default       : READ_DATA2_o = gpr[READ_ADDR2_i];
    endcase
  end
endmodule