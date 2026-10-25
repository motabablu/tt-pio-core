// ============================================================================
// Outbound Protocol Test: 16-Bit MSB-First SPI Master TX (Mode 0) + CRC-16
// Pin Mapping on PAD_OUT_o:
//   Bit 0 (0x0001) : MOSI
//   Bit 1 (0x0002) : SCK
//   Bit 2 (0x0004) : CS_n (Active Low)
// ============================================================================

    // Configure Pin Direction & Bootstrap Constants (Zero FIFO Use)
    SMU_CMD CLR                 // R_SMU <= 0xFFFF
    MOV     R_PIN_DIR, R_SMU    // Set all pins as outputs (0xFFFF)

    SMU_CMD LFSR                // R_SMU <= 0xFFFE (15 ones = odd parity)
    MOV     R_SMU, R_SMU        // Latch 0xFFFE into SMU input
    SMU_CMD PARITY              // R_SMU <= 0x0001!
    MOV     R1, R_SMU           // R1 = 0x0001 (Constant 1 / MOSI mask)
    ADD     R2, R1, R1          // R2 = 0x0002 (Constant 2 / SCK mask)
    ADD     R3, R2, R2          // R3 = 0x0004 (Constant 4 / CS_n mask)
    SLL     R4, R1, R3          // R4 = 1 << 4 = 16 (Bit loop counter = 16)

    // Idle State: Drive CS_n High (0x0004), SCK = 0, MOSI = 0
    MOV     R_PIN_OUT, R3       // PAD_OUT <= 0x0004 (CS_n deasserted)
    DELAY   4                   // Hold bus idle

    // Pop Payload Word, Compute CRC-16, and Bit-Reverse for MSB-First
    POP     R5                  // R5 <= Payload word from H2C FIFO
    SMU_CMD CLR                 // Seed CRC accumulator to 0xFFFF
    MOV     R_SMU, R5           // Load payload into SMU input
    SMU_CMD CRC16               // R_SMU <= CRC-16 of payload
    PUSH    R_SMU               // Push CRC-16 to C2H FIFO for scoreboard check

    SMU_CMD BITREV              // R_SMU <= Bit-reversed payload (MSB is now at bit 0)
    MOV     R5, R_SMU           // R5 <= Shifter register (MSB at LSB position)

    // Assert CS_n Low (0x0000) to Begin Frame
    MOV     R_PIN_OUT, R0       // PAD_OUT <= 0x0000 (CS_n asserted low)
    DELAY   2                   // Setup time before first clock bit

    // 16-Bit Serial Shift Loop (SPI Mode 0)
bit_loop:
    AND     R6, R5, R1          // R6 = Current MOSI bit (R5 & 1)
    MOV     R_PIN_OUT, R6       // Drive MOSI (SCK = 0, CS_n = 0)
    DELAY   2                   // Data setup time (SCK low phase)

    OR      R7, R6, R2          // R7 = MOSI | SCK (0x0002)
    MOV     R_PIN_OUT, R7       // Rising edge of SCK! Slave samples MOSI
    DELAY   3                   // SCK high phase

    MOV     R_PIN_OUT, R6       // Falling edge of SCK (keep MOSI stable)
    SRL     R5, R5, R1          // Shift next bit into LSB (R5 >>= 1)
    SUB     R4, R4, R1          // Decrement bit counter (R4 -= 1)
    JNZ     bit_loop            // Loop until all 16 bits are transmitted

    // End of Frame: Clear MOSI/SCK, Return CS_n High (0x0004)
    MOV     R_PIN_OUT, R0       // Ensure SCK=0, MOSI=0
    DELAY   2                   // Hold time before CS_n deasserts
    MOV     R_PIN_OUT, R3       // Deassert CS_n High (0x0004)
    DELAY   4                   // Hold idle state before halting

halt_loop:
    JMP     halt_loop           // Halt