`timescale 1ns / 1ps
`default_nettype none

module ASIC_TOP (
  input   logic         CLK_i,
  input   logic         RESET_n_i,
  input   logic         SPI_SCK_i,
  input   logic         SPI_MOSI_i,
  output  logic         SPI_MISO_o,
  input   logic         SPI_CS_n_i,
  input   logic [15:0]  PAD_IN_i,
  output  logic [15:0]  PAD_OUT_o,
  output  logic [15:0]  PAD_DIR_o
);

  logic [15:0]  pad_in_meta;
  logic [15:0]  pad_in_sync;
  logic [15:0]  pc;
  logic [15:0]  imem_data_rd;
  logic         core_reset_n;
  logic         imem_write_en;
  logic [15:0]  imem_write_addr;
  logic [15:0]  imem_write_data;
  logic [15:0]  h2c_data_i;
  logic         h2c_push;
  logic         h2c_full;
  logic [15:0]  h2c_data_o;
  logic         h2c_pop;
  logic         h2c_empty;
  logic [15:0]  c2h_data_i;
  logic         c2h_push;
  logic         c2h_full;
  logic [15:0]  c2h_data_o;
  logic         c2h_pop;
  logic         c2h_empty;
  logic [15:0]  smu_data_to_core;
  logic [15:0]  smu_data_from_core;
  logic         smu_cmd_en;

  always_ff @(posedge CLK_i or negedge RESET_n_i) begin
    if (!RESET_n_i) begin
      pad_in_meta <= '0;
      pad_in_sync <= '0;
    end else begin
      pad_in_meta <= PAD_IN_i;
      pad_in_sync <= pad_in_meta;
    end
  end

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
  
  DP_SRAM u_imem (
    .CLK_i      (CLK_i),
    .ADDR_RD_i  (pc),
    .DATA_RD_o  (imem_data_rd),
    .WE_i       (imem_write_en),
    .ADDR_WR_i  (imem_write_addr),
    .DATA_WR_i  (imem_write_data)
  );
  
  CORE_TOP u_core (
    .CLK_i        (CLK_i),
    .RESET_n_i    (core_reset_n),
    .PC_o         (pc),
    .INSTR_i      (imem_data_rd),
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
  
  SMU u_smu (
    .CLK_i        (CLK_i),
    .RESET_n_i    (core_reset_n),
    .SMU_CMD_EN_i (smu_cmd_en),
    .SMU_OP_i     (imem_data_rd[11:8]), 
    .SMU_DATA_i   (smu_data_from_core),
    .SMU_DATA_o   (smu_data_to_core)
  );
endmodule