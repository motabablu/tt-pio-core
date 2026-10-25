`default_nettype none

module tt_um_pio_core (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    wire [15:0] pad_in;
    wire [15:0] pad_out;
    wire [15:0] pad_dir;

    // Map UIO [7:0] to lower 8 bits of pad
    assign pad_in[7:0]  = uio_in;
    assign uio_out      = pad_out[7:0];
    assign uio_oe       = pad_dir[7:0];

    // Map upper 8 bits of pad to dedicated UI/UO
    assign pad_in[15:8] = {3'b000, ui_in[7:3]};

    // ui_in[2:0] used for SPI
    // uo_out[0] used for SPI MISO
    assign uo_out[7:1]  = pad_out[14:8];

    ASIC_TOP u_asic_top (
        .CLK_i      (clk),
        .RESET_n_i  (rst_n),
        .SPI_SCK_i  (ui_in[0]),
        .SPI_MOSI_i (ui_in[1]),
        .SPI_CS_n_i (ui_in[2]),
        .SPI_MISO_o (uo_out[0]),
        .PAD_IN_i   (pad_in),
        .PAD_OUT_o  (pad_out),
        .PAD_DIR_o  (pad_dir)
    );

endmodule