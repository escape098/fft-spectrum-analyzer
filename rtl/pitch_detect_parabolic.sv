// ===================================================================
// pitch_detect_parabolic.v
// 支持 FFT 点数：128 / 256 / 512
// Fs = 48 kHz
// 使用三点抛物线插值找到精确主频
// ===================================================================

module pitch_detect_parabolic #(
    parameter SCALE_FACTOR = 100     // 输出 x100
)(
    input  wire        clk,
    input  wire        resetn,

    // FFT 点数 (128 / 256 / 512)
    input  wire [9:0]  fft_npoint,

    // 输入：来自 FFT 幅值模块
    input  wire        mag_valid,
    input  wire [15:0] magnitude,
    input  wire [9:0]  point_index,
    input  wire        mag_last,

    // 输出：插值后的频率 (x100)
    output reg         freq_valid,
    output reg [15:0]  detected_freq,

    // 输出：最大 bin 与 幅值
    output reg [9:0]   max_mag_index,
    output reg [15:0]  max_magnitude
);

// Q16 精确频率分辨率：Fs/N = 48000/N

localparam [31:0] FREQ_RES_128_Q16 = 32'h0177_0000; // 375.00
localparam [31:0] FREQ_RES_256_Q16 = 32'h00BB_8000; // 187.50
localparam [31:0] FREQ_RES_512_Q16 = 32'h005D_C000; // 93.75

reg [31:0] freq_res_q16;
always @(*) begin
    case (fft_npoint)
        10'd128: freq_res_q16 = FREQ_RES_128_Q16;
        10'd256: freq_res_q16 = FREQ_RES_256_Q16;
        10'd512: freq_res_q16 = FREQ_RES_512_Q16;
        default: freq_res_q16 = FREQ_RES_512_Q16;
    endcase
end

// 状态寄存器

reg [15:0] current_max_magnitude;
reg [9:0]  current_max_index;

reg [15:0] mag_prev;
reg [9:0]  idx_prev;

reg [15:0] left_mag, center_mag, right_mag;

reg frame_processing;

reg signed [17:0] num;
reg signed [18:0] den;
reg signed [27:0] offset1024;
reg signed [27:0] k_est1024;

reg signed [63:0] freq_mul_q16;
reg [31:0]         freq_tmp;

// 输出滤波寄存器

reg [31:0] filtered_freq;    // IIR 放大1024倍
reg        has_valid_freq;   // 是否已有历史
reg [15:0] detected_freq_raw;

// 主逻辑

always @(posedge clk) begin
    if (!resetn) begin
        freq_valid <= 0;
        detected_freq <= 0;

        current_max_magnitude <= 0;
        current_max_index     <= 0;

        left_mag   <= 0;
        center_mag <= 0;
        right_mag  <= 0;

        mag_prev <= 0;
        idx_prev <= 0;

        max_mag_index <= 0;
        max_magnitude <= 0;

        frame_processing <= 0;

        filtered_freq  <= 0;
        has_valid_freq <= 0;

    end else begin
        freq_valid <= 0;

        // 上一拍保存
        if (mag_valid) begin
            mag_prev <= magnitude;
            idx_prev <= point_index;
        end


        if (mag_valid && point_index == 2) begin
            frame_processing <= 1;

            current_max_magnitude <= magnitude;
            current_max_index     <= 2;

            left_mag   <= mag_prev;
            center_mag <= magnitude;
            right_mag  <= 0;
        end

        // 峰值检测：忽略 bin0、bin1

        if (frame_processing && mag_valid) begin

            // 只搜索 2..N/2
            if (point_index >= 2 && point_index <= (fft_npoint >> 1)) begin
                if (magnitude > current_max_magnitude) begin
                    current_max_magnitude <= magnitude;
                    current_max_index     <= point_index;

                    left_mag   <= mag_prev;
                    center_mag <= magnitude;
                    right_mag  <= 0;
                end
            end

            // 右侧点捕获
            if (idx_prev == current_max_index)
                right_mag <= magnitude;

           
            // 一帧结束：做插值 + 输出滤波
            
            if (mag_last) begin
                frame_processing <= 0;

                // ----- 三点抛物线插值 -----
                num = $signed({1'b0,left_mag}) -
                      $signed({1'b0,right_mag});

                den = $signed({2'b0,left_mag})
                    - ($signed({2'b0,center_mag}) <<< 1)
                    + $signed({2'b0,right_mag});

                if (den == 0)
                    den = 1;

                offset1024 = (num <<< 9) / (den <<< 1);

                k_est1024 = (($signed({1'b0,current_max_index}) - 1) <<< 10)
                           + offset1024;

                freq_mul_q16 = k_est1024 * freq_res_q16;

                freq_tmp = freq_mul_q16 >> (16 + 10);
                
                // 原始频率结果（未经滤波）
                
                detected_freq_raw <= (freq_tmp[31:16] != 0) ?
                                     16'hFFFF : freq_tmp[15:0];

                // 频率滤波（忽略 0xFFFF）

                if (detected_freq_raw != 16'hFFFF) begin
                    if (!has_valid_freq) begin
                        filtered_freq  <= detected_freq_raw << 10;
                        detected_freq  <= detected_freq_raw;
                        has_valid_freq <= 1;
                    end else begin
                        // IIR 低通滤波: y = y - y/8 + x/8
                        filtered_freq <= filtered_freq
                                       - (filtered_freq >>> 3)
                                       + ((detected_freq_raw << 10) >>> 3);

                        detected_freq <= filtered_freq >>> 10;
                    end
                end
                // 若等于 0xFFFF，则保持 detected_freq 不变

                max_mag_index <= current_max_index;
                max_magnitude <= current_max_magnitude;
                freq_valid    <= 1;
            end
        end
    end
end

endmodule
