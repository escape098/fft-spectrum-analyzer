// ===================================================================
// seg7_buffer.v
// 八段数码管驱动
// 集成了bcd转换
// 同时输出转换后的bcd码给显示渲染模块
// ===================================================================
`timescale 1ns/1ps
module seg7_buffer (
    input  wire        clk,           // 100MHz 时钟
    input  wire        resetn,        // 低有效复位
    input  wire        freq_valid,    // 新数据有效
    input  wire [15:0] detected_freq, // 频率
    
    output reg  [7:0]  seg_en,      
    output reg  [7:0]  seg0_data,   
    output reg  [7:0]  seg1_data,   
    output reg   [3:0] digit[7:0]
);

    localparam SCAN_DIV = 100_000_000 / 8000;
    reg [15:0] scan_div = 0;
    reg [2:0]  scan_id  = 0;

    always @(posedge clk) begin
        if (!resetn) begin
            scan_div <= 0;
            scan_id  <= 0;
        end else begin
            if (scan_div == SCAN_DIV-1) begin
                scan_div <= 0;
                scan_id <= scan_id + 1;
            end else begin
                scan_div <= scan_div + 1;
            end
        end
    end


    reg [31:0] tmp;
    integer i;
    always @(*) begin
        tmp = detected_freq;
        for (i = 0; i < 8; i = i + 1) begin
            digit[i] = tmp % 10;
            tmp = tmp / 10;
        end
    end

    function [7:0] seg_code;
        input [3:0] d;
        begin
            case (d)
                4'd0: seg_code = 8'b11000000;
                4'd1: seg_code = 8'b11111001;
                4'd2: seg_code = 8'b10100100;
                4'd3: seg_code = 8'b10110000;
                4'd4: seg_code = 8'b10011001;
                4'd5: seg_code = 8'b10010010;
                4'd6: seg_code = 8'b10000010;
                4'd7: seg_code = 8'b11111000;
                4'd8: seg_code = 8'b10000000;
                4'd9: seg_code = 8'b10010000;
                default: seg_code = 8'b11111111;
            endcase
        end
    endfunction


    always @(*) begin
        seg_en = 8'b0000_0000;
        seg_en[scan_id] = 1'b1;

        seg0_data = 8'h00;
        seg1_data = 8'h00;
        case (scan_id)
            3'd0, 3'd1, 3'd2, 3'd3: begin
                seg1_data = ~seg_code(digit[scan_id]);
                seg0_data = 8'h00;
            end
            3'd4, 3'd5, 3'd6, 3'd7: begin
                seg0_data = ~seg_code(digit[scan_id]);
                seg1_data = 8'h00;
            end
        endcase
    end
endmodule