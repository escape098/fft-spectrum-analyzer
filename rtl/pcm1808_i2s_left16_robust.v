// ===================================================================
// pcm1808_i2s_left16_robust.v
// pcm1808数据接收模块，串->并
// 直接收左声道，高16位
// ===================================================================
`timescale 1ns/1ps
module pcm1808_i2s_left16_robust (
   input  wire        clk,
    input  wire        resetn,
    input  wire        bck,
    input  wire        lrck,
    input  wire        sdata,

    output reg         data_valid,
    output reg [15:0]  audio_data,
    output reg         sync_error
);

parameter LEFT_LEVEL   = 1'b0;  // PCM1808：左声道 LRCK = 0
parameter SAMPLE_BITS  = 24;    // 固定：PCM1808 输出始终 24bit
parameter OUT_BITS     = 16;    // 输出 16bit
parameter BCK_TIMEOUT  = 2000;

reg [2:0] bck_s, lrck_s, sd_s;

always @(posedge clk) begin
    if (!resetn) begin
        bck_s  <= 0;
        lrck_s <= 0;
        sd_s   <= 0;
    end else begin
        bck_s  <= {bck_s[1:0],  bck};
        lrck_s <= {lrck_s[1:0], lrck};
        sd_s   <= {sd_s[1:0],   sdata};
    end
end

wire bck_rise = (bck_s[2:1] == 2'b01);


reg [SAMPLE_BITS-1:0] shift_reg;
reg [4:0]             bit_cnt;
reg                   capturing_left;
reg                   lrck_saved;

reg [OUT_BITS-1:0]    next_audio;
reg                   next_valid;

reg [31:0]            bck_timeout_ctr;

always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        shift_reg       <= 0;
        bit_cnt         <= 0;
        capturing_left  <= 0;
        lrck_saved      <= 0;

        next_audio      <= 0;
        next_valid      <= 0;

        data_valid      <= 0;
        audio_data      <= 0;
        sync_error      <= 0;

        bck_timeout_ctr <= 0;
    end
    else begin
        data_valid <= 0;

        // ---------------------------------------------------------------------
        // BCK 超时检测
        // ---------------------------------------------------------------------
        if (bck_rise) begin
            bck_timeout_ctr <= 0;
            sync_error <= 0;
        end else if (bck_timeout_ctr < 32'h7FFFFFFF) begin
            bck_timeout_ctr <= bck_timeout_ctr + 1;
        end

        if (bck_timeout_ctr >= BCK_TIMEOUT) begin
            sync_error <= 1;
            bit_cnt <= 0;
            capturing_left <= 0;
        end

        // ---------------------------------------------------------------------
        // I2S 数据接收
        // ---------------------------------------------------------------------
        if (bck_rise) begin
            
            // LRCK 边沿 → 开始新的声道
            if (lrck_s[2] != lrck_saved) begin
                lrck_saved     <= lrck_s[2];
                capturing_left <= (lrck_s[2] == LEFT_LEVEL);
                bit_cnt        <= 0;       // 新声道 bit0
                shift_reg      <= 0;       // 清空移位寄存器
            end
            else begin
                if (capturing_left) begin
                    // 始终移位
                    shift_reg <= {shift_reg[SAMPLE_BITS-2:0], sd_s[2]};
                    bit_cnt <= bit_cnt + 1;
                    if (bit_cnt == SAMPLE_BITS) begin
                        next_audio <= shift_reg[SAMPLE_BITS-1 : SAMPLE_BITS-OUT_BITS];
                        next_valid <= 1'b1;
                        bit_cnt <= 0;
                    end
                end
                else begin
                    // 右声道：保持同步用
                    if (bit_cnt == SAMPLE_BITS) begin
                        bit_cnt <= 0;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            end
        end

        // ---------------------------------------------------------------------
        // 输出到系统时钟域
        // ---------------------------------------------------------------------
        if (next_valid) begin
            audio_data <= next_audio;
            data_valid <= 1;
            next_valid <= 0;
        end
    end
end

endmodule 