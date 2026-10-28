`timescale 1ns / 1ps
`default_nettype none

import CORE_PKG::*;

module SPI (
  input   logic                     CLK_i,
  input   logic                     RESET_n_i,
  
  // SPI pins
  input   logic                     SPI_SCK_i,
  input   logic                     SPI_MOSI_i,
  output  logic                     SPI_MISO_o,
  input   logic                     SPI_CS_n_i,
  
  // IMEM
  output  logic                     IMEM_WE_o,
  output  logic [INSTR_WIDTH - 1:0] IMEM_ADDR_o,
  output  logic [INSTR_WIDTH - 1:0] IMEM_DATA_o,
  output  logic                     CORE_RELEASE_o,
  
  // H2C FIFO
  output  logic [DATA_WIDTH - 1:0]  H2C_DATA_o,
  output  logic                     H2C_PUSH_o,
  input   logic                     H2C_FULL_i,
  
  // C2H FIFO
  input   logic [DATA_WIDTH - 1:0]  C2H_DATA_i,
  output  logic                     C2H_POP_o,
  input   logic                     C2H_EMPTY_i
);

  // 2-FF sync
  logic [2:0] sck_sync;
  logic [1:0] cs_n_sync;
  logic [1:0] mosi_sync;
  
  // Sync (sequential)
  always_ff @(posedge CLK_i or negedge RESET_n_i) begin
    if (!RESET_n_i) begin
      sck_sync  <= 3'b000;
      cs_n_sync <= 2'b11;
      mosi_sync <= 2'b00;
    end else begin
      sck_sync  <= {sck_sync[1:0], SPI_SCK_i};
      cs_n_sync <= {cs_n_sync[0], SPI_CS_n_i};
      mosi_sync <= {mosi_sync[0], SPI_MOSI_i};
    end // RESET_n_i
  end // CLK_i, RESET_n_i
  
  // Edge detection
  logic sck_rising;
  logic sck_falling;
  logic cs_active;
  
  // Edge detection (combinational)
  assign sck_rising   = (sck_sync[2:1] == 2'b01);
  assign sck_falling  = (sck_sync[2:1] == 2'b10);
  assign cs_active    = ~cs_n_sync[1];
  
  // Counters
  localparam int CMD_WIDTH  = 8;
  localparam int FRAME_BITS = CMD_WIDTH + INSTR_WIDTH + DATA_WIDTH;
  localparam int CNT_WIDTH  = $clog2(FRAME_BITS + 1);
  
  logic [CNT_WIDTH - 1:0]   bit_cnt;
  logic [FRAME_BITS - 1:0]  rx_shift_reg;
  logic [DATA_WIDTH - 1:0]  tx_shift_reg;
  
  // Decoded fields
  spi_cmd_e                 current_cmd;
  logic [INSTR_WIDTH - 1:0] rx_addr;
  logic [DATA_WIDTH - 1:0]  rx_data;
  logic [FRAME_BITS - 1:0]  full_rx_frame;
  
  assign full_rx_frame  = {rx_shift_reg[FRAME_BITS - 2:0], mosi_sync[1]};
  assign current_cmd    = spi_cmd_e'(full_rx_frame[FRAME_BITS - 1 : INSTR_WIDTH + DATA_WIDTH]);
  assign rx_addr        = full_rx_frame[INSTR_WIDTH + DATA_WIDTH - 1 : DATA_WIDTH];
  assign rx_data        = full_rx_frame[DATA_WIDTH - 1:0];
  
  // FSM (sequential)
  always_ff @(posedge CLK_i or negedge RESET_n_i) begin
    if (!RESET_n_i) begin
      // Defaults
      bit_cnt         <= '0;
      rx_shift_reg    <= '0;
      tx_shift_reg    <= '0;
      SPI_MISO_o      <= 1'b0;
      CORE_RELEASE_o  <= 1'b0;
      IMEM_WE_o       <= 1'b0;
      IMEM_ADDR_o     <= '0;
      IMEM_DATA_o     <= '0;
      H2C_DATA_o      <= '0;
      H2C_PUSH_o      <= 1'b0;
      C2H_POP_o       <= 1'b0;
    end else begin
      // Defaults
      IMEM_WE_o   <= 1'b0;
      H2C_PUSH_o  <= 1'b0;
      C2H_POP_o   <= 1'b0;
      
      if (!cs_active) begin
        bit_cnt     <= '0;
        SPI_MISO_o  <= 1'b0;
      end else begin
        if (sck_rising) begin
          rx_shift_reg  <= full_rx_frame;
          bit_cnt       <= bit_cnt + 1'b1;
          
          if (bit_cnt == 6'(CMD_WIDTH - 1)) begin
            case (spi_cmd_e'({rx_shift_reg[CMD_WIDTH - 2:0], mosi_sync[1]}))
              SPI_CMD_POP_C2H : begin
                tx_shift_reg  <= C2H_DATA_i;
                C2H_POP_o     <= 1'b1;
              end
              SPI_CMD_READ_STAT : begin
                tx_shift_reg <= {{(DATA_WIDTH - 2){1'b0}}, H2C_FULL_i, C2H_EMPTY_i};
              end
              default : tx_shift_reg <= '0;
            endcase // spi_cmd_e, rx_shift_reg, CMD_WIDTH, mosi_sync
          end // bit_cnt, CMD_WIDTH
          
          if (bit_cnt == 6'(FRAME_BITS - 1)) begin
            case (current_cmd)
              SPI_CMD_RESET_HOLD : begin
                CORE_RELEASE_o <= 1'b0;
              end
              SPI_CMD_RESET_REL : begin
                CORE_RELEASE_o <= 1'b1;
              end
              SPI_CMD_WRITE_IMEM : begin
                IMEM_ADDR_o <= rx_addr;
                IMEM_DATA_o <= rx_data;
                IMEM_WE_o   <= 1'b1;
              end
              SPI_CMD_PUSH_H2C : begin
                H2C_DATA_o  <= rx_data;
                H2C_PUSH_o  <= 1'b1;
              end
              
              default : ;
            endcase // current_cmd
          end // bit_cnt, FRAME_BITS
        end // sck_rising
        
        if (sck_falling) begin
          if (bit_cnt >= 6'(CMD_WIDTH + INSTR_WIDTH)) begin
            SPI_MISO_o    <= tx_shift_reg[DATA_WIDTH - 1];
            tx_shift_reg  <= {tx_shift_reg[DATA_WIDTH - 2:0], 1'b0};
          end else begin
            SPI_MISO_o    <= 1'b0;
          end // bit_cnt, CMD_WIDTH, INSTR_WIDTH
        end // sck_falling
        
      end // cs_active
    end // RESET_n_i
  end // always_ff

endmodule