// Multi-Word H2C Stream + SMU Byteswap + C2H Push Test
    SMU_CMD CLR                 // R_SMU <= 0xFFFF
    MOV     R_PIN_DIR, R_SMU    // Configure all pins as outputs (0xFFFF)

    // --- Word 0 ---
    POP     R1                  // Pop H2C[0]
    MOV     R_PIN_OUT, R1       // Drive H2C[0] on pins
    DELAY   4                   // Hold for 4 stall cycles (+1 MOV cycle = 5 cycles)

    // --- Word 1 ---
    POP     R2                  // Pop H2C[1]
    MOV     R_PIN_OUT, R2       // Drive H2C[1] on pins
    DELAY   7                   // Hold for 7 stall cycles (+1 MOV cycle = 8 cycles)

    // --- Word 2 (Drive on pins + Byteswap via SMU + Push to C2H) ---
    POP     R3                  // Pop H2C[2]
    MOV     R_PIN_OUT, R3       // Drive H2C[2] on pins
    MOV     R_SMU, R3           // Load H2C[2] into SMU input register
    SMU_CMD BYTESWAP            // R_SMU <= Byte-swapped H2C[2]
    PUSH    R_SMU               // Push byte-swapped result into C2H FIFO

    // --- Clear Pins & Halt ---
    MOV     R_PIN_OUT, R0       // Clear pins back to 0x0000

halt_loop:
    JMP     halt_loop           // Halt