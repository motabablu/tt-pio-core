// ============================================================================
// Inbound Protocol 2: 8-Bit Serial Slave Deserializer + CRC-16 Verification
//   Pin 0 (0x0001) : Output READY / DONE
//   Pin 1 (0x0002) : Input EXT_SCK
//   Pin 2 (0x0004) : Input EXT_SDI
// ============================================================================

    // --- 1. Bootstrap Constants (1, 2, 8) & Configure Pin 0 as Output ---
    SMU_CMD CLR                 // R_SMU <= 0xFFFF
    SMU_CMD LFSR                // R_SMU <= 0xFFFE
    MOV     R_SMU, R_SMU        // Latch 0xFFFE
    SMU_CMD PARITY              // R_SMU <= 0x0001
    MOV     R1, R_SMU           // R1 = 1 (Constant 1)
    ADD     R2, R1, R1          // R2 = 2 (Constant 2 / Shift count for Pin 2)
    ADD     R3, R2, R1          // R3 = 3
    SLL     R4, R1, R3          // R4 = 8 (8-bit loop counter)

    MOV     R_PIN_DIR, R1       // Pin 0 = Output, Pins [15:1] = Inputs
    MOV     R_PIN_OUT, R1       // Assert READY High (0x0001) while receiving
    MOV     R5, R0              // R5 = 0x0000 (Clear RX shift register)

    // --- 2. 8-Bit Serial Deserialization Loop ---
rx_bit_loop:
    WEDGE   1, 1                // Wait for Rising Edge on EXT_SCK (Pin 1)
    MOV     R6, R_PIN_IN        // Sample input pins on clock edge
    SRL     R6, R6, R2          // Shift Pin 2 (EXT_SDI) down to bit 0 (R6 >>= 2)
    AND     R6, R6, R1          // Mask isolated data bit (R6 & 1)
    SLL     R5, R5, R1          // Shift RX accumulator left by 1 (R5 <<= 1)
    OR      R5, R5, R6          // Merge new LSB into RX accumulator

    WEDGE   1, 0                // Wait for Falling Edge on EXT_SCK before next bit
    SUB     R4, R4, R1          // Decrement bit counter
    JNZ     rx_bit_loop         // Loop until all 8 bits are deserialized

    // --- 3. Push Reconstructed Byte (0x00A5) & Its CRC-16 to C2H FIFO ---
    PUSH    R5                  // C2H_FIFO[0] <= 0x00A5
    SMU_CMD CLR                 // Reset CRC accumulator to 0xFFFF
    MOV     R_SMU, R5           // Load received byte (0x00A5) into SMU
    SMU_CMD CRC16               // Compute CRC-16
    PUSH    R_SMU               // C2H_FIFO[1] <= CRC-16(0x00A5)

    MOV     R_PIN_OUT, R0       // Clear READY Low (0x0000) to signal frame complete

halt_loop:
    JMP     halt_loop           // Halt