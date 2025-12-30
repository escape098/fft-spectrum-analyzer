// ===========================================================
// glyph_64x128_from_8x16.v
// 8x16 font expanded to 64x128 (X8 scaling)
// ===========================================================
`timescale 1ns/1ps

module glyph_64x128_from_8x16 (
    input  wire        clk,
    input  wire        resetn,
    input  wire [7:0]  ch,
    input  wire [6:0]  px_x,   // 0..63
    input  wire [6:0]  px_y,   // 0..127
    output reg         pixel_on
);
    wire [3:0] font_row = px_y[6:3];    // /8
    wire [2:0] font_bit = px_x[5:3];    // /8

    wire [7:0] row_bits;
    font8x16_rom font_u(
        .ch(ch),
        .row(font_row),
        .bits(row_bits)
    );

    always @(posedge clk) begin
        if(!resetn)
            pixel_on <= 0;
        else
            pixel_on <= row_bits[7 - font_bit];
    end

endmodule

// ===========================================================
// glyph_32x64_from_8x16.v
// 8x16 font expanded to 32x64 (X4 scaling)
// ===========================================================
`timescale 1ns/1ps

module glyph_32x64_from_8x16 (
    input  wire        clk,
    input  wire        resetn,
    input  wire [7:0]  ch,
    input  wire [5:0]  px_x,   // 0..31
    input  wire [5:0]  px_y,   // 0..63
    output reg         pixel_on
);
    // 4倍缩放：32/8 = 4, 64/16 = 4
    // 将32x64坐标映射回8x16的坐标
    wire [3:0] font_row = px_y[5:2];    // /4，取高4位 (0..15)
    wire [2:0] font_bit = px_x[5:2];    // /4，取高3位 (0..7)

    wire [7:0] row_bits;
    font8x16_rom font_u(
        .ch(ch),
        .row(font_row),
        .bits(row_bits)
    );

    always @(posedge clk) begin
        if(!resetn)
            pixel_on <= 0;
        else
            // 根据缩小的字体位选择像素
            pixel_on <= row_bits[7 - font_bit];
    end

endmodule