`timescale 1ns / 1ps
`default_nettype none

module ASIC_TOP (
  input   logic     CLK_i,
  input   logic     RESET_n_i,
  
  // SPI interface
  input   logic     SPI_SCK_i,
  input   logic     SPI_MOSI_i,
  output  logic     SPI_MISO_o,
  input   logic     SPI_CS_n_i,
  
  // Pins
  input   logic [CORE_PKG::DATA_WIDTH - 1:0]  PAD_IN_i,
  output  logic [CORE_PKG::DATA_WIDTH - 1:0]  PAD_OUT_o,
  output  logic [CORE_PKG::DATA_WIDTH - 1:0]  PAD_DIR_o
);
  
  import CORE_PKG::*;

  // 2 FF sync
  logic [DATA_WIDTH - 1:0]  pad_in_meta;
  logic [DATA_WIDTH - 1:0]  pad_in_sync;

  // Core
  logic [PC_WIDTH - 1:0]    pc;
  instr_t                   instr;
  logic                     core_reset_n;
  
  // Imem
  logic                     imem_write_en;
  logic [INSTR_WIDTH - 1:0] imem_write_addr;
  logic [INSTR_WIDTH - 1:0] imem_write_data;
  
  // H2C FIFO
  logic [DATA_WIDTH - 1:0]  h2c_data_i;
  logic                     h2c_push;
  logic                     h2c_full;
  logic [DATA_WIDTH - 1:0]  h2c_data_o;
  logic                     h2c_pop;
  logic                     h2c_empty;
  
  //C2H FIFO
  logic [DATA_WIDTH - 1:0]  c2h_data_i;
  logic                     c2h_push;
  logic                     c2h_full;
  logic [DATA_WIDTH - 1:0]  c2h_data_o;
  logic                     c2h_pop;
  logic                     c2h_empty;
  
  // SMU
  logic [DATA_WIDTH - 1:0]  smu_data_to_core;
  logic [DATA_WIDTH - 1:0]  smu_data_from_core;
  logic                     smu_cmd_en;
  
  // 2 FF Sync
  always_ff @(posedge CLK_i or negedge RESET_n_i) begin
    if (!RESET_n_i) begin
      pad_in_meta <= '0;
      pad_in_sync <= '0;
    end else begin
      pad_in_meta <= PAD_IN_i;
      pad_in_sync <= pad_in_meta;
    end // RESET_n_i
  end // CLK_i, RESET_n_i

  // SPI
  SPI u_spi (
    .CLK_i          (CLK_i),
    .RESET_n_i      (RESET_n_i),
    .SPI_SCK_i      (SPI_SCK_i),
    .SPI_MOSI_i     (SPI_MOSI_i),
    .SPI_MISO_o     (SPI_MISO_o),
    .SPI_CS_n_i     (SPI_CS_n_i),
    .IMEM_WE_o      (imem_write_en),
    .IMEM_ADDR_o    (imem_write_addr),
    .IMEM_DATA_o    (imem_write_data),
    .CORE_RELEASE_o (core_reset_n),
    .H2C_DATA_o     (h2c_data_i),
    .H2C_PUSH_o     (h2c_push),
    .H2C_FULL_i     (h2c_full),
    .C2H_DATA_i     (c2h_data_o),
    .C2H_POP_o      (c2h_pop),
    .C2H_EMPTY_i    (c2h_empty)    
  );
  
  // Instruction Memory
  DP_SRAM u_imem (
    .CLK_i      (CLK_i),
    .ADDR_RD_i  (pc),
    .DATA_RD_o  (instr),
    .WE_i       (imem_write_en),
    .ADDR_WR_i  (imem_write_addr),
    .DATA_WR_i  (imem_write_data)
  );
  
  // Core
  CORE_TOP u_core (
    .CLK_i        (CLK_i),
    .RESET_n_i    (core_reset_n),
    .PC_o         (pc),
    .INSTR_i      (instr),
    .PIN_IN_i     (pad_in_sync),
    .PIN_OUT_o    (PAD_OUT_o),
    .PIN_DIR_o    (PAD_DIR_o),
    .SMU_DATA_i   (smu_data_to_core),
    .SMU_DATA_o   (smu_data_from_core),
    .SMU_CMD_EN_o (smu_cmd_en),
    .FIFO_DATA_i  (h2c_data_o),
    .FIFO_DATA_o  (c2h_data_i),
    .FIFO_PUSH_o  (c2h_push),
    .FIFO_POP_o   (h2c_pop)
  );
  
  // H2C FIFO
  FIFO u_h2c_fifo (
    .CLK_i      (CLK_i),
    .RESET_n_i  (RESET_n_i),
    .DATA_i     (h2c_data_i),
    .PUSH_i     (h2c_push),
    .FULL_o     (h2c_full),
    .DATA_o     (h2c_data_o),
    .POP_i      (h2c_pop),
    .EMPTY_o    (h2c_empty)
  );
  
  // C2H FIFO
  FIFO u_c2h_fifo (
    .CLK_i      (CLK_i),
    .RESET_n_i  (RESET_n_i),
    .DATA_i     (c2h_data_i),
    .PUSH_i     (c2h_push),
    .FULL_o     (c2h_full),
    .DATA_o     (c2h_data_o),
    .POP_i      (c2h_pop),
    .EMPTY_o    (c2h_empty)
  );
  
  // SMU
  SMU u_smu (
    .CLK_i        (CLK_i),
    .RESET_n_i    (core_reset_n),
    .SMU_CMD_EN_i (smu_cmd_en),
    .SMU_OP_i     (smu_op_e'(instr.dest_reg)),
    .SMU_DATA_i   (smu_data_from_core),
    .SMU_DATA_o   (smu_data_to_core)
  );

endmodule