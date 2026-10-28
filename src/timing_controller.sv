`timescale 1ns / 1ps
`default_nettype none

module TIMING_CTRL (
  input  logic                        CLK_i,
  input  logic                        RESET_n_i,
   
  // Decoder control signals
  input  logic                        DELAY_EN_i,
  input  logic [CORE_PKG::IMM_WIDTH - 1:0]      DELAY_VAL_i,
  input  logic                        WAIT_EDGE_EN_i,
  input  logic [CORE_PKG::REG_ADDR_WIDTH - 1:0] EDGE_PIN_i,
  input  logic                        EDGE_POLARITY_i,
   
  // Physical pins
  input  logic [CORE_PKG::DATA_WIDTH - 1:0]     PIN_IN_i,
   
  // Stall
  output logic                        STALL_o
);

  import CORE_PKG::*;

  logic [IMM_WIDTH - 1:0]  delay_counter;
  logic [DATA_WIDTH - 1:0] pin_in_prev;
  
  logic edge_detected;
  logic active_delay;

  // Edge detection (combinational)
  always_comb begin
    edge_detected = 1'b0;
    if (EDGE_POLARITY_i == 1'b1) begin
      edge_detected = (~pin_in_prev[EDGE_PIN_i]) & PIN_IN_i[EDGE_PIN_i];
    end else begin
      edge_detected = pin_in_prev[EDGE_PIN_i] & (~PIN_IN_i[EDGE_PIN_i]);
    end // EDGE_POLARITY_i
  end // always_comb

  // Stall (combinational)
  always_comb begin
    STALL_o = 1'b0;
    if (DELAY_EN_i && (DELAY_VAL_i > 0)) begin
      // Stall while counting down, release when counter reaches 1 on active_delay
      if (!active_delay) begin
        STALL_o = (DELAY_VAL_i > 1);
      end else begin
        STALL_o = (delay_counter > 1);
      end // active_delay
    end // DELAY_EN_i, DELAY_VAL_i
    else if (WAIT_EDGE_EN_i) begin
      STALL_o = ~edge_detected;
    end // WAIT_EDGE_EN_i
  end // always_comb

  // Delay (sequential)
  always_ff @(posedge CLK_i or negedge RESET_n_i) begin
    if (!RESET_n_i) begin
      delay_counter <= '0;
      pin_in_prev   <= '0;
      active_delay  <= 1'b0;
    end else begin
      pin_in_prev <= PIN_IN_i;

      if (DELAY_EN_i && (DELAY_VAL_i > 1)) begin
        if (!active_delay) begin
          // First cycle of DELAY N: load (N - 1)
          active_delay  <= 1'b1;
          delay_counter <= DELAY_VAL_i - 1'b1;
        end // active_delay
        else if (delay_counter > 1) begin
          // Middle cycles of DELAY N: count down
          delay_counter <= delay_counter - 1'b1;
        end else begin
          // Final cycle of DELAY N: STALL_o is now 0, PC advances on this edge
          active_delay  <= 1'b0;
          delay_counter <= '0;
        end // delay_counter
      end else begin
        active_delay  <= 1'b0;
        delay_counter <= '0;
      end // DELAY_EN_i, DELAY_VAL_i
    end // RESET_n_i
  end // CLK_i, RESET_n_i

endmodule