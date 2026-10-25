// ============================================================================
// Inbound Protocol Test 1: WEDGE Rising/Falling Handshake + R_PIN_IN Capture
//   Pin 0 (0x0001) : Output ACK
//   Pin 1 (0x0002) : Input REQ/Strobe (monitored by WEDGE)
//   Pins [15:8]    : Input Data Bus
// ============================================================================

    // --- 1. Bootstrap Constant 1 & Set Pin 0 as Output, Pins [15:1] as Inputs ---
    SMU_CMD CLR                 // R_SMU <= 0xFFFF
    SMU_CMD LFSR                // R_SMU <= 0xFFFE
    MOV     R_SMU, R_SMU        // Latch 0xFFFE
    SMU_CMD PARITY              // R_SMU <= 0x0001
    MOV     R1, R_SMU           // R1 = 0x0001
    MOV     R_PIN_DIR, R1       // PAD_DIR <= 0x0001 (Pin 0 = Output, [15:1] = Inputs)

    // --- 2. Wait for Rising Edge on Pin 1 (Polarity = 1) ---
    WEDGE   1, 1                // Stall until PAD_IN_i[1] transitions 0 -> 1
    MOV     R2, R_PIN_IN        // Sample live PAD_IN_i (0xA502)
    PUSH    R2                  // Push sampled word to C2H_FIFO[0]
    MOV     R_PIN_OUT, R1       // Assert ACK High (PAD_OUT_o <= 0x0001)

    // --- 3. Wait for Falling Edge on Pin 1 (Polarity = 0) ---
    WEDGE   1, 0                // Stall until PAD_IN_i[1] transitions 1 -> 0
    MOV     R3, R_PIN_IN        // Sample live PAD_IN_i (0x3C00)
    MOV     R_SMU, R3           // Load into SMU
    SMU_CMD BYTESWAP            // Swap bytes (0x3C00 -> 0x003C)
    PUSH    R_SMU               // Push swapped word to C2H_FIFO[1]
    MOV     R_PIN_OUT, R0       // Clear ACK Low (PAD_OUT_o <= 0x0000)

halt_loop:
    JMP     halt_loop           // Halt