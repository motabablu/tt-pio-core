// ============================================================================
// Protocol Test: CAN Bus Transmit & ACK Slot (Dominant/Recessive)
//   Pin 0 (0x0001) : CAN_TX (Output) - Recessive=1, Dominant=0
//   Pin 1 (0x0002) : CAN_RX (Input)
// ============================================================================

    // --- 1. Bootstrap Constants & Configure Direction ---
    SMU_CMD CLR                 // R_SMU <= 0xFFFF
    SMU_CMD LFSR                // R_SMU <= 0xFFFE
    MOV     R_SMU, R_SMU        // Latch 0xFFFE
    SMU_CMD PARITY              // R_SMU <= 0x0001
    MOV     R1, R_SMU           // R1 = 1 (Constant 1 / TX Pin mask)
    MOV     R_PIN_DIR, R1       // PAD_DIR <= 0x0001 (Pin 0 TX Output, Pin 1 RX Input)
    
    ADD     R2, R1, R1          // R2 = 2 (RX Pin mask)
    ADD     R3, R2, R2          // R3 = 4
    ADD     R4, R3, R3          // R4 = 8 (8-bit ID for this test frame)

    // --- 2. Bus Idle (Recessive) ---
    MOV     R_PIN_OUT, R1       // TX = 1 (Recessive)
    DELAY   8                   // Hold Idle state

    // --- 3. Start of Frame (SOF - Dominant) ---
    MOV     R_PIN_OUT, R0       // TX = 0 (Dominant)
    DELAY   4                   // 1 CAN bit period

    // --- 4. Transmit Identifier (Pop from H2C) ---
    POP     R5                  // R5 <= H2C[0] (Frame ID)
tx_loop:
    AND     R6, R5, R1          // Isolate LSB (R5 & 1)
    MOV     R_PIN_OUT, R6       // Drive bit onto CAN_TX
    DELAY   4                   // 1 CAN bit period
    SRL     R5, R5, R1          // Shift next bit into LSB
    SUB     R4, R4, R1          // Decrement counter
    JNZ     tx_loop             // Loop until ID is transmitted

    // --- 5. ACK Slot (Drive Recessive, Sample for Dominant) ---
    MOV     R_PIN_OUT, R1       // Drive TX Recessive (1) to allow slave to ACK
    DELAY   2                   // Wait half a bit period (propagation delay)
    MOV     R7, R_PIN_IN        // Sample live CAN_RX (Pin 1)
    AND     R7, R7, R2          // Mask RX pin (R7 & 2)
    PUSH    R7                  // Push sampled ACK bit to C2H FIFO
    DELAY   2                   // Finish ACK bit period

    // --- 6. End of Frame (EOF - 7 Recessive bits) ---
    MOV     R_PIN_OUT, R1       // Drive TX Recessive (1)
    DELAY   28                  // Hold for 7 bit periods (7 * 4 cycles)

halt_loop:
    JMP     halt_loop           // Halt