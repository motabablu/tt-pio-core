// ============================================================================
// Outbound Protocol 3: Pulse-Width Modulated (WS2812B / 1-Wire Style) Bitstream
// Tests JZ + JNZ dual-path timing and SMU SETPOLY / SETSEED
// ============================================================================

    // --- 1. Configure Pin Direction & Bootstrap Constants ---
    SMU_CMD CLR                 // R_SMU <= 0xFFFF
    MOV     R_PIN_DIR, R_SMU    // Set all pins as outputs (0xFFFF)

    SMU_CMD LFSR                // R_SMU <= 0xFFFE
    MOV     R_SMU, R_SMU        // Latch 0xFFFE
    SMU_CMD PARITY              // R_SMU <= 0x0001
    MOV     R1, R_SMU           // R1 = 1
    ADD     R2, R1, R1          // R2 = 2
    ADD     R3, R2, R1          // R3 = 3
    SLL     R4, R1, R3          // R4 = 8 (Transmit 8 PWM-encoded bits)

    // --- 2. Pop Word0 (Custom Polynomial) & Word1 (Data Payload) ---
    POP     R5                  // R5 <= H2C[0]
    MOV     R_SMU, R5           // Load H2C[0] into SMU
    SMU_CMD SETPOLY             // poly_reg <= H2C[0]

    POP     R6                  // R6 <= H2C[1] (Payload to transmit)
    MOV     R_SMU, R6           // Load H2C[1] into SMU
    SMU_CMD SETSEED             // acc_reg <= H2C[1]
    SMU_CMD LFSR                // Step LFSR once using custom poly & seed
    PUSH    R_SMU               // Push LFSR result to C2H FIFO

    // --- 3. 8-Bit PWM Bitstream Loop (Tests JZ and JMP branching) ---
pwm_loop:
    AND     R7, R6, R1          // Test LSB (sets q_zero_flag if bit == 0)
    JZ      send_zero           // Branch if bit is '0'

send_one:                       // Bit == '1': Long High, Short Low
    MOV     R_PIN_OUT, R1       // Drive High (0x0001)
    DELAY   6                   // Long High pulse
    MOV     R_PIN_OUT, R0       // Drive Low (0x0000)
    DELAY   2                   // Short Low pulse
    JMP     bit_done

send_zero:                      // Bit == '0': Short High, Long Low
    MOV     R_PIN_OUT, R1       // Drive High (0x0001)
    DELAY   2                   // Short High pulse
    MOV     R_PIN_OUT, R0       // Drive Low (0x0000)
    DELAY   6                   // Long Low pulse

bit_done:
    SRL     R6, R6, R1          // Shift next bit into LSB
    SUB     R4, R4, R1          // Decrement bit counter
    JNZ     pwm_loop            // Repeat for 8 bits

halt_loop:
    JMP     halt_loop           // Halt