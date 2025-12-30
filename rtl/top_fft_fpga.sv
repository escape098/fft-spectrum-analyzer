// 综合上板的顶层模块：音频频谱分析仪
`timescale 1ns/1ps

module top_fft_fpga (
    // 系统时钟和复位
    input  wire        clk_100m,      // 100MHz主时钟
    input  wire        reset_btn,     // 复位按钮（低有效）
    
    // PCM1808音频接口
    input  wire        pcm_sdata,     // 串行音频数据
    output wire        pcm_mclk,      // 主时钟（12.288MHz）
    output wire        pcm_bck,       // 位时钟（3.072MHz）
    output wire        pcm_lrck,      // 左右声道时钟（48kHz）
    
    // 数码管显示
    output wire [7:0]  seg_en,        // 数码管位选
    output wire [7:0]  seg0_data,     // 左侧数码管段选
    output wire [7:0]  seg1_data,     // 右侧数码管段选

    
    // VGA显示输出
    output wire        hsync_n,       // 行同步（低有效）
    output wire        vsync_n,       // 场同步（低有效）
    output wire [3:0]  vga_r,         // 红色分量
    output wire [3:0]  vga_g,         // 绿色分量
    output wire [3:0]  vga_b,         // 蓝色分量
    
    // 物理按键
    input  wire        key0,          // KEY0：VGA分辨率切换
    input  wire        key1,          // KEY1：FFT点数切换
    input  wire        key2,          // KEY2：自动量程切换
    input  wire        key3,          // KEY3：保留
    input  wire        key4           // KEY4：保留
);

// 系统控制信号
wire        clk;            // 系统主时钟（100MHz）
wire        resetn;         // 全局复位（低有效）
wire        pix_clk;        // VGA像素时钟
wire        pix_clk_720;    // 720p像素时钟（74.25MHz）
wire        pix_clk_1080;   // 1080p像素时钟（148.5MHz）
wire        locked;         // 时钟锁相标志

// 按键信号
wire        key0_edge;      // KEY0上升沿
wire        key1_edge;      // KEY1上升沿
wire        key2_edge;      // KEY2上升沿
wire        key3_edge;      // KEY3上升沿
wire        key4_edge;      // KEY4上升沿

// PCM音频接口
wire        pcm_data_valid; // PCM数据有效标志
wire [15:0] pcm_audio_data; // PCM音频数据（16位）
wire        pcm_sync_error; // PCM同步错误标志

// FFT缓冲接口
wire [15:0] buf_dout_real;  // 缓冲输出（实部）
wire        buf_dout_valid; // 缓冲输出有效
wire        buf_dout_last;  // 缓冲最后一帧
wire        fft_reset_pulse;// FFT复位脉冲

// FFT处理接口
wire        mag_valid;      // 幅度数据有效
wire [15:0] real_part;      // FFT实部结果
wire [15:0] imag_part;      // FFT虚部结果
wire [15:0] magnitude;      // 幅度值
wire        mag_last;       // 幅度最后一帧
wire [8:0]  point_index;    // 频点索引

// 音高检测接口
wire        freq_valid;     // 频率检测有效
wire [15:0] detected_freq;  // 检测到的基频（Hz）
wire [8:0]  max_mag_index;  // 最大幅度索引
wire [15:0] max_magnitude;  // 最大幅度值

// 音名检测接口
wire [7:0]  note_ascii1;    // 音名第一个字符（A-G）
wire [7:0]  note_ascii2;    // 音名第二个字符（#或空格）
wire [7:0]  note_octave;    // 八度字符（0-8）

// 波形采样接口
wire        buf_ready;      // 采样缓冲就绪
wire [15:0] dout;           // 波形数据输出
wire [10:0] rd_addr;        // 波形读地址

// 频谱显示接口
wire [7:0]  vga_bin_index;  // 频谱RAM读地址
wire [15:0] vga_mag_data;   // 频谱RAM数据输出
wire        fft_we;         // FFT写使能
wire [15:0] fft_data;       // FFT写数据
wire [7:0]  fft_addr;       // FFT写地址

// 数码管位值
wire [3:0]  digit[7:0];     // 数码管显示的BCD码

// VGA显示控制
wire        visible;        // 有效显示区域
wire [11:0] x;              // 像素X坐标
wire [10:0] y;              // 像素Y坐标
wire [3:0]  bar_r;          // 柱状图红色分量
wire [3:0]  bar_g;          // 柱状图绿色分量
wire [3:0]  bar_b;          // 柱状图蓝色分量

// 配置管理接口
wire        video_mode;     // 0=720p，1=1080p
wire [1:0]  fft_sel;        // FFT点数选择：00=128,01=256,10=512
wire [9:0]  frame_size;     // 实际FFT点数
wire        auto_range;     // 自动量程使能
wire [23:0] cfg_data_sel;   // FFT配置数据

assign clk = clk_100m;      // 主时钟
assign pix_clk = video_mode ? pix_clk_1080 : pix_clk_720; // 像素时钟

// 复位按钮同步（防止亚稳态）
reg [3:0] reset_sync_reg;
assign resetn = reset_sync_reg[3];

always @(posedge clk) begin
    reset_sync_reg <= {reset_sync_reg[2:0], reset_btn};
end

// VGA时钟生成器（720p和1080p双模式）
clk_wiz_0 u_clkgen (
    .clk_in1 (clk_100m),    // 100MHz输入
    .reset   (~resetn),     // 复位（高有效）
    .clk_out1(pix_clk_1080),// 1080p像素时钟
    .clk_out2(pix_clk_720), // 720p像素时钟
    .locked  (locked)       // PLL锁定标志
);

// I2S时钟生成器（为PCM1808提供时钟）
i2s_clock_gen u_i2s_clk (
    .clk_100m(clk_100m),    // 100MHz输入
    .rst_n   (resetn),      // 复位（低有效）
    .mclk    (pcm_mclk),    // 主时钟12.288MHz
    .bck     (pcm_bck),     // 位时钟3.072MHz
    .lrck    (pcm_lrck)     // 左右声道时钟48kHz
);

// 按键消抖模块（5个独立按键）
keys_debounce u_keys (
    .clk        (clk),          // 时钟
    .resetn     (resetn),       // 复位
    
    .key0_raw   (key0),         // 原始按键输入
    .key1_raw   (key1),
    .key2_raw   (key2),
    .key3_raw   (key3),
    .key4_raw   (key4),
    
    .key0_edge  (key0_edge),    // 消抖后的边沿
    .key1_edge  (key1_edge),
    .key2_edge  (key2_edge),
    .key3_edge  (key3_edge),
    .key4_edge  (key4_edge)
);

// 配置管理模块
config_manager u_config_manager (
    .clk          (clk),          // 系统时钟
    .resetn       (resetn),       // 系统复位
    
    // 按键输入
    .key0_edge    (key0_edge),    // VGA分辨率切换
    .key1_edge    (key1_edge),    // FFT点数切换
    .key2_edge    (key2_edge),    // 自动量程切换
    .key3_edge    (key3_edge),    // 保留按键
    .key4_edge    (key4_edge),    // 保留按键
    
    // 配置输出
    .video_mode   (video_mode),   // VGA分辨率模式
    .fft_sel      (fft_sel),      // FFT点数选择
    .frame_size   (frame_size),   // 实际FFT点数
    .auto_range   (auto_range),   // 自动量程使能
    .cfg_data_sel (cfg_data_sel)  // FFT配置数据
);

// PCM1808 I2S接收器（只接收左声道）
pcm1808_i2s_left16_robust u_pcm_rx (
    .clk        (clk),          // 系统时钟
    .resetn     (resetn),       // 复位
    .bck        (pcm_bck),      // 位时钟
    .lrck       (pcm_lrck),     // 左右声道时钟
    .sdata      (pcm_sdata),    // 串行数据
    
    .data_valid (pcm_data_valid), // 数据有效脉冲
    .audio_data (pcm_audio_data), // 16位音频数据
    .sync_error (pcm_sync_error)  // 同步错误标志
);

// 音频缓冲和帧同步
buffer_fft u_buf (
    .clk            (clk),          // 系统时钟
    .resetn         (resetn),       // 复位
    .frame_size     (frame_size),   // FFT点数
    .din            (pcm_audio_data), // 输入音频数据
    .din_valid      (pcm_data_valid),// 输入有效
    .dout_real      (buf_dout_real), // 输出实部（虚部固定为0）
    .dout_valid     (buf_dout_valid),// 输出有效
    .dout_last      (buf_dout_last), // 帧结束标志
    .fft_reset_pulse(fft_reset_pulse) // FFT复位脉冲
);

// FFT计算核（包含加窗和幅度计算）
fft512_with_window u_fft (
    // 时钟和复位
    .clk            (clk),                  // 系统时钟
    .resetn         (resetn),               // FFT复位
    
    // 输入接口
    .raw_data_valid (buf_dout_valid),       // 原始数据有效
    .raw_data_real  (buf_dout_real),        // 原始实部数据
    .raw_data_imag  (16'd0),                // 虚部固定为0
    .raw_data_last  (buf_dout_last),        // 帧结束
    
    // 配置接口
    .s_axis_config_tvalid(1'b1),            // 配置始终有效
    .s_axis_config_tdata (cfg_data_sel),    // 配置数据
    .fft_points          (frame_size),      // FFT点数
    .auto_range          (auto_range),      // 自动量程
    
    // 输出接口
    .mag_valid    (mag_valid),              // 幅度数据有效
    .real_part    (real_part),              // 实部结果
    .imag_part    (imag_part),              // 虚部结果
    .magnitude_sq (),                       // 幅度平方（未使用）
    .magnitude    (magnitude),              // 幅度值
    .mag_last     (mag_last),               // 最后频点
    .point_index  (point_index),            // 频点索引
    
    // FFT核状态
    .m_axis_data_tready (1'b1),             // 始终准备好接收
    
    // BRAM写接口（用于VGA显示）
    .fft_addr     (fft_addr),               // 写地址
    .fft_data     (fft_data),               // 写数据
    .fft_we       (fft_we)                  // 写使能
);

// 三点抛物线插值主频检测
pitch_detect_parabolic pitch_inst (
    .clk           (clk),                   // 时钟
    .resetn        (resetn),                // 复位
    .fft_npoint    (frame_size),            // FFT点数
    .mag_valid     (mag_valid),             // 幅度有效
    .magnitude     (magnitude),             // 幅度值
    .point_index   (point_index),           // 频点索引
    .mag_last      (mag_last),              // 最后频点
    .freq_valid    (freq_valid),            // 频率有效
    .detected_freq (detected_freq),         // 检测频率（Hz）
    .max_mag_index (max_mag_index),         // 最大幅度索引
    .max_magnitude (max_magnitude)          // 最大幅度值
);

// 音名检测（将频率转换为音符名）
note_name_detect u_note_name_detect (
    .clk          (clk_100m),               // 100MHz时钟
    .resetn       (resetn),                 // 复位
    .detected_freq(detected_freq),          // 输入频率
    .freq_valid   (freq_valid),             // 频率有效
    .note_ascii1  (note_ascii1),            // 音名字符1
    .note_ascii2  (note_ascii2),            // 音名字符2
    .note_octave  (note_octave)             // 八度字符
);

// 数码管显示（显示频率和音符）
seg7_buffer u_seg (
    .clk           (clk),                   // 时钟
    .resetn        (resetn),                // 复位
    .freq_valid    (freq_valid),            // 频率有效
    .detected_freq (detected_freq),         // 检测频率
    .seg_en        (seg_en),                // 数码管位选
    .seg0_data     (seg0_data),             // 左侧数码管
    .seg1_data     (seg1_data),             // 右侧数码管
    .digit         (digit[7:0])             // BCD码输出
);

// 采样器（采集波形用于VGA显示）
zero_cross_sampler_1920_bram_addr sampler_u (
    .wr_clk    (clk),                       // 写时钟（100MHz）
    .din       (pcm_audio_data),            // PCM音频输入
    .din_valid (pcm_data_valid),            // 数据有效
    .rd_clk    (pix_clk),                   // 读时钟（VGA像素时钟）
    .rd_addr   (rd_addr),                   // 读地址（来自VGA模块）
    .dout      (dout),                      // 波形数据输出
    .buf_ready (buf_ready)                  // 缓冲就绪标志
);

// 频谱RAM（双端口，FFT写，VGA读）
mag_ram_dp u_mag_ram (
    // 端口A：FFT写入
    .clk_a  (clk_100m),                     // FFT时钟
    .addr_a (fft_addr),                     // FFT写地址
    .din_a  (fft_data),                     // FFT写数据
    .we_a   (fft_we),                       // FFT写使能
    
    // 端口B：VGA读取
    .clk_b  (pix_clk),                      // VGA像素时钟
    .addr_b (vga_bin_index),                // VGA读地址
    .dout_b (vga_mag_data)                  // VGA读数据
);

// VGA频谱和波形渲染器
bar_render_pixel_sync u_bar (
    // 时钟和模式
    .pix_clk_1080  (pix_clk_1080),          // 1080p像素时钟
    .pix_clk_720   (pix_clk_720),           // 720p像素时钟
    
    .mode_sel      (video_mode),            // 分辨率模式
    .resetn        (resetn),                // 复位
    
    // 像素位置
    .visible       (visible),               // 有效显示区域
    .x             (x),                     // X坐标
    .y             (y),                     // Y坐标
    
    // 频谱数据
    .fft_npoint    (frame_size),            // FFT点数
    .ram_addr      (vga_bin_index),         // 频谱RAM读地址
    .ram_dout      (vga_mag_data),          // 频谱RAM数据
    
    // 波形数据
    .wave_buf_addr (rd_addr),               // 波形RAM读地址
    .wave_buf_dout (dout),                  // 波形数据
    
    // 音符显示
    .note_ascii1   (note_ascii1),           // 音名1
    .note_ascii2   (note_ascii2),           // 音名2
    .note_octave   (note_octave),           // 八度
    
    // 数码管值
    .digit         (digit[4:0]),            // 数码管显示的数值
    
    // 量程控制
    .auto_range    (auto_range),            // 自动量程使能
    
    // RGB输出
    .out_r         (bar_r),                 // 红色分量
    .out_g         (bar_g),                 // 绿色分量
    .out_b         (bar_b)                  // 蓝色分量
);

// VGA时序发生器（支持720p和1080p）
vga_dynamic u_vga (
    // 时钟输入
    .clk_148m        (pix_clk_1080),        // 148.5MHz（1080p）
    .clk_37m         (pix_clk_720),         // 74.25MHz（720p）
    .resetn          (resetn & locked),     // 复位（需时钟锁定）
    .mode_sel        (video_mode),          // 分辨率选择
    
    // 像素输入
    .in_r            (bar_r),               // 红色输入
    .in_g            (bar_g),               // 绿色输入
    .in_b            (bar_b),               // 蓝色输入
    .use_input_pixel (1'b1),                // 使用外部像素
    
    // VGA输出
    .hsync_n         (hsync_n),             // 行同步
    .vsync_n         (vsync_n),             // 场同步
    .vga_r           (vga_r),               // 红色输出
    .vga_g           (vga_g),               // 绿色输出
    .vga_b           (vga_b),               // 蓝色输出
    
    // 像素位置输出
    .visible         (visible),             // 有效区域标志
    .x               (x),                   // X坐标
    .y               (y)                    // Y坐标
);

endmodule