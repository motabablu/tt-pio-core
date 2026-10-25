// ============================================================================
// Protocol Test: Manchester Encoder (IEEE 802.3 Convention)
// Pin Mapping on PAD_OUT_o:
//   Bit 0 (0x0001) : TX Output
// ============================================================================

    // Bootstrap Constants & Configure Direction
    SMU_CMD CLR                 // R_SMU <= 0xFFFF
    SMU_CMD LFSR                // R_SMU <= 0xFFFE
    MOV     R_SMU, R_SMU        // Latch 0xFFFE
    SMU_CMD PARITY              // R_SMU <= 0x0001
    MOV     R1, R_SMU           // R1 = 1 (TX Pin mask / Logic 1)
    MOV     R_PIN_DIR, R1       // PAD_DIR <= 0x0001 (Pin 0 is Output)
    
    ADD     R2, R1, R1          // R2 = 2
    ADD     R3, R2, R2          // R3 = 4
    SLL     R4, R1, R3          // R4 = 16 (16-bit payload counter)

    // Idle State (Low)
    MOV     R_PIN_OUT, R0       // Idle line at 0
    DELAY   4                   // Hold idle

    // Pop Payload
    POP     R5                  // R5 <= H2C[0] (16-bit payload)

    // Manchester Bit-Banging Loop
manchester_loop:
    AND     R6, R5, R1          // Isolate LSB (R5 & 1)
    JZ      send_zero           // Branch if data bit is 0

send_one:                       // Logic 1: 0 -> 1 transition
    MOV     R_PIN_OUT, R0       // Drive 0 (First half)
    DELAY   3
    MOV     R_PIN_OUT, R1       // Drive 1 (Second half)
    DELAY   3
    JMP     next_bit

send_zero:                      // Logic 0: 1 -> 0 transition
    MOV     R_PIN_OUT, R1       // Drive 1 (First half)
    DELAY   3
    MOV     R_PIN_OUT, R0       // Drive 0 (Second half)
    DELAY   3

next_bit:
    SRL     R5, R5, R1          // Shift payload right
    SUB     R4, R4, R1          // Decrement counter
    JNZ     manchester_loop     // Loop until 16 bits transmitted

    // Return to Idle
    MOV     R_PIN_OUT, R0       // Return to idle (0)
    DELAY   4

halt_loop:
    JMP     halt_loop           // Halt