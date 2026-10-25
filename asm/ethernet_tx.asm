// ============================================================================
// Protocol Test: 10BASE-T Ethernet PHY (Manchester Encoded)
// Features: Nested Looping, Dynamic Frame Length, TP_IDL Link Pulse
// Pin Mapping:
//   Pin 0 (0x0001) : TX Differential Output
// ============================================================================

    // --- 1. Bootstrap Constants & Configure Direction ---
    SMU_CMD CLR                 // R_SMU <= 0xFFFF
    SMU_CMD LFSR                // R_SMU <= 0xFFFE
    MOV     R_SMU, R_SMU        
    SMU_CMD PARITY              // R_SMU <= 0x0001
    MOV     R1, R_SMU           // R1 = 1 (TX Pin mask / Logic 1)
    MOV     R_PIN_DIR, R1       // PAD_DIR <= 0x0001 (Pin 0 Output)
    
    ADD     R2, R1, R1          // R2 = 2
    ADD     R3, R2, R2          // R3 = 4
    SLL     R4, R1, R3          // R4 = 16 (Bits per word)

    // --- 2. Idle State (0V Differential) ---
    MOV     R_PIN_OUT, R0       // Idle line at 0
    DELAY   8                   // Hold idle

    // --- 3. Pop Word Count (Outer Loop setup) ---
    POP     R11                 // R11 <= Number of 16-bit words in frame

word_loop:
    POP     R5                  // R5 <= Next 16-bit word from H2C FIFO
    MOV     R10, R4             // R10 = 16 (Reset inner bit counter)

bit_loop:
    AND     R6, R5, R1          // Isolate LSB (R5 & 1)
    JZ      send_zero           // Branch if data bit is 0

    // --- Logic 1 (0 -> 1 transition) ---
send_one:                       
    MOV     R_PIN_OUT, R0       // Drive 0 (First half)
    DELAY   9                   // 1 + 9 = 10 cycles
    MOV     R_PIN_OUT, R1       // Drive 1 (Second half)
    DELAY   3                   // 1 + 3 + 1 (JMP) + 5 (Loop) = 10 cycles
    JMP     next_bit

    // --- Logic 0 (1 -> 0 transition) ---
send_zero:                      
    MOV     R_PIN_OUT, R1       // Drive 1 (First half)
    DELAY   9                   // 1 + 9 = 10 cycles
    MOV     R_PIN_OUT, R0       // Drive 0 (Second half)
    DELAY   4                   // 1 + 4 + 0 (No JMP) + 5 (Loop) = 10 cycles

next_bit:
    SRL     R5, R5, R1          // Shift payload right
    SUB     R10, R10, R1        // Decrement bit counter
    JNZ     bit_loop            // Loop until 16 bits transmitted

    SUB     R11, R11, R1        // Decrement word counter
    JNZ     word_loop           // Jump to next word if R11 > 0

    // --- 4. TP_IDL (Normal Link Pulse / End of Transmission) ---
    // Ethernet standard requires driving the line High for ~3 bit times before Idle
    MOV     R_PIN_OUT, R1       
    DELAY   60                  // Hold High for 3 bit times (3 * 20 cycles)
    MOV     R_PIN_OUT, R0       // Return to Idle (0V)

halt_loop:
    JMP     halt_loop