// =================================================================== 
// fft_512_with_window.v
// - 封装了两个ip核，前面加上了汉宁窗，后面加上了幅度计算
// - 本模块 hann_window_coeff.sv 提供 HANN_128[], HANN_256[], HANN_512[] (16-bit)
// - fft_points 必须为 128 / 256 / 512（其他值未特别支持）
// - 本模块只将 FFT 输出的前 (fft_points/2) 写入 BRAM（addr 0..fft_points/2-1）
// ===================================================================

`timescale 1ns/1ps
`include "hann_window_coeff.sv"

module fft512_with_window (
    input  wire        clk,
    input  wire        resetn,

    // 可变点数输入（128 / 256 / 512）
    input  wire [9:0]  fft_points,        // e.g. 128,256,512

    // 原始数据输入接口（来自 buffer）
    input  wire        raw_data_valid,
    input  wire [15:0] raw_data_real,
    input  wire [15:0] raw_data_imag,
    input  wire        raw_data_last,

    // FFT 配置接口（AXIS）
    input  wire        s_axis_config_tvalid,
    input  wire [7:0]  s_axis_config_tdata,
    input  wire       auto_range,
    // 幅度输出接口（与原接口保持一致）
    output reg         mag_valid,
    output reg [15:0]  real_part,
    output reg [15:0]  imag_part,
    output reg [31:0]  magnitude_sq,
    output reg [15:0]  magnitude,
    output reg         mag_last,
    output reg [8:0]   point_index,

    // 控制信号
    input  wire        m_axis_data_tready,

    // Safe RAM write outputs
    output reg [7:0]   fft_addr,   // 写 RAM 地址（0..255）
    output reg [15:0]  fft_data,
    output reg         fft_we
);

// -----------------------------
// window 处理
// -----------------------------
reg [8:0] sample_counter;   // 能容纳到 511
reg        mult_valid, mult_last;
reg [31:0] real_product, imag_product;

reg        windowed_valid;
reg        windowed_last;
reg [15:0] windowed_real;
reg [15:0] windowed_imag;

wire [15:0] window_coeff;
// 选择合适的窗系数，根据 fft_points 和 sample_counter
// 假设数组索引都从 0 开始，且长度与 fft_points 对应
reg [15:0] window_coeff_r;

always @(*) begin
    case (fft_points)
        10'd128: window_coeff_r = hann_window_coeff::HANN_128[sample_counter];
        10'd256: window_coeff_r = hann_window_coeff::HANN_256[sample_counter];
        default: window_coeff_r = hann_window_coeff::HANN_512[sample_counter];
    endcase
end
assign window_coeff = window_coeff_r;

// 窗乘（阶段1）：Q1.15 * Q1.15 -> Q2.30
always @(posedge clk) begin
    if (!resetn) begin
        real_product <= 32'd0;
        imag_product <= 32'd0;
        mult_valid   <= 1'b0;
        mult_last    <= 1'b0;
        sample_counter <= 9'd0;
    end else begin
        if (raw_data_valid) begin
            // 有效数据进来，计算乘法
            real_product <= $signed(raw_data_real) * $signed(window_coeff);
            imag_product <= $signed(raw_data_imag) * $signed(window_coeff);
            mult_valid <= 1'b1;
            mult_last <= raw_data_last;

            // 更新采样计数器（按 fft_points 周期）
            if (raw_data_last) begin
                sample_counter <= 9'd0;
            end else begin
                // 增加并在达到 fft_points-1 时回绕
                if (sample_counter >= (fft_points - 1))
                    sample_counter <= 9'd0;
                else
                    sample_counter <= sample_counter + 1;
            end
        end else begin
            mult_valid <= 1'b0;
            mult_last <= 1'b0;
        end
    end
end

// 窗处理阶段2：格式转换 Q2.30 -> Q1.15（右移15）
always @(posedge clk) begin
    if (!resetn) begin
        windowed_valid <= 1'b0;
        windowed_last  <= 1'b0;
        windowed_real  <= 16'd0;
        windowed_imag  <= 16'd0;
    end else begin
        windowed_valid <= mult_valid;
        windowed_last  <= mult_last;
        if (mult_valid) begin
            // 取 [30:15]
            windowed_real <= real_product[30:15];
            windowed_imag <= imag_product[30:15];
        end
    end
end

// -----------------------------
// FFT 输入数据组合（连接到 XFFT IP）
// -----------------------------
wire [31:0] fft_input_data;
assign fft_input_data = {windowed_imag, windowed_real};

// -----------------------------
// XFFT IP 接口信号（wire）
// -----------------------------
wire        fft0_out_valid;
wire [31:0] fft0_out_data;
wire        fft0_out_last;

wire        fft0_data_tready;
wire        fft0_cfg_tready;

xfft_0 fft512_inst (
    .aclk(clk),

    .s_axis_data_tvalid(windowed_valid),
    .s_axis_data_tready(fft0_data_tready),
    .s_axis_data_tdata(fft_input_data),
    .s_axis_data_tlast(windowed_last),

    .s_axis_config_tvalid(s_axis_config_tvalid),
    .s_axis_config_tready(fft0_cfg_tready),
    .s_axis_config_tdata(s_axis_config_tdata),

    .m_axis_data_tvalid(fft0_out_valid),
    .m_axis_data_tdata(fft0_out_data),
    .m_axis_data_tlast(fft0_out_last),
    .m_axis_data_tready(m_axis_data_tready)
);

//----------------------------------------------
// 新增 FFT 实例（自动量程）
//----------------------------------------------
wire        fftA_out_valid;
wire [31:0] fftA_out_data;
wire        fftA_out_last;

wire        fftA_data_tready;
wire        fftA_cfg_tready;

// 新 FFT：自动量程版本
xfft_auto fft_auto_inst (
    .aclk(clk),

    .s_axis_data_tvalid(windowed_valid),
    .s_axis_data_tready(fftA_data_tready),
    .s_axis_data_tdata(fft_input_data),
    .s_axis_data_tlast(windowed_last),

    .s_axis_config_tvalid(s_axis_config_tvalid),
    .s_axis_config_tready(fftA_cfg_tready),
    .s_axis_config_tdata(s_axis_config_tdata),

    .m_axis_data_tvalid(fftA_out_valid),
    .m_axis_data_tdata(fftA_out_data),
    .m_axis_data_tlast(fftA_out_last),
    .m_axis_data_tready(m_axis_data_tready),
    .m_axis_status_tready(1'b1) 
);

//------------------------------------------------------
// 选择输出：根据 auto_range 决定走哪个 FFT（核心逻辑）
//------------------------------------------------------

wire        fft_out_valid = (auto_range ? fftA_out_valid : fft0_out_valid);
wire [31:0] fft_out_data  = (auto_range ? fftA_out_data  : fft0_out_data );
wire        fft_out_last  = (auto_range ? fftA_out_last  : fft0_out_last );

// -----------------------------
// 幅度计算（保留原 approx_sqrt）
// -----------------------------
reg [31:0] temp_real_sq, temp_imag_sq;
reg [31:0] temp_magnitude_sq;
reg [8:0]  internal_point_index;     

function [15:0] approx_sqrt;
    input [31:0] value;
    reg [31:0] temp;
    reg [15:0] result;
    integer i;
    begin
        temp = value;
        result = 0;
        for (i = 15; i >= 0; i = i - 1) begin
            if ((result | (1 << i)) * (result | (1 << i)) <= temp)
                result = result | (1 << i);
        end
        approx_sqrt = result;
    end
endfunction

always @(posedge clk) begin
    if (!resetn) begin
        mag_valid <= 1'b0;
        mag_last  <= 1'b0;

        real_part <= 16'b0;
        imag_part <= 16'b0;
        magnitude_sq <= 32'b0;
        magnitude    <= 16'b0;

        internal_point_index <= 9'd0;
        point_index <= 9'd0;

    end else if (fft_out_valid && m_axis_data_tready) begin

        // ==== 提取实虚部 ====
        real_part <= fft_out_data[15:0];
        imag_part <= fft_out_data[31:16];

        // ==== 计算平方 ====
        temp_real_sq = $signed(real_part) * $signed(real_part);
        temp_imag_sq = $signed(imag_part) * $signed(imag_part);
        temp_magnitude_sq = temp_real_sq + temp_imag_sq;

        magnitude_sq <= temp_magnitude_sq;
        magnitude    <= approx_sqrt(temp_magnitude_sq);

        // ==== 有效标志 ====
        mag_valid <= 1'b1;

        // ==== 正确的 mag_last ====
        // 只依赖 FFT IP 的 last 信号，不会提前
        mag_last <= fft_out_last;

        // ==== index 自增 ====
        point_index <= internal_point_index;
        internal_point_index <= internal_point_index + 1;

        // ==== 末尾清零 ====
        if (fft_out_last)
            internal_point_index <= 9'd0;

    end else begin
        mag_valid <= 1'b0;
        mag_last  <= 1'b0;
    end
end

// 寄存器定义
reg [7:0]  process_addr;  // 当前正在处理的 bin 地址
reg        write_done;
reg        start_skip;

// 三级流水线控制
reg        stage1_valid;
reg        stage2_valid;
reg        stage3_valid;

// Stage1 锁存：锁存当前 bin 的所有信息
reg [15:0] s1_mag;        // 当前帧幅值
reg [7:0]  s1_addr;       // bin 地址
reg [15:0] s1_prev_mag;   // 上一帧幅值（从 RAM 读出）

// Stage2 计算：IIR 滤波计算
reg [15:0] s2_filt_mag;   // 滤波后的值
reg [7:0]  s2_addr;       // bin 地址

// Stage3 计算：频率加权
reg [15:0] s3_weighted_mag;  // 加权后的值
reg [15:0] s3_filt_mag;      // 未加权的滤波值（用于更新RAM）
reg [7:0]  s3_addr;          // bin 地址

// 上一帧幅值 RAM
reg [15:0] prev_frame_mag [0:255];

// 参数
wire [9:0] output_half = fft_points >> 1;
wire [7:0] max_addr    = output_half[7:0] - 1;
localparam IIR_SHIFT = 4;

// 循环变量（模块级声明）
integer i;

// 10*ln(index) 查找表 (定点数，缩放 256 倍)
// ln(1) = 0, ln(2) = 0.693, ln(3) = 1.099, ...
// 10*ln(x)*256 的近似值
reg [15:0] log_lut [0:255];
reg [31:0] mult_tmp;


localparam integer LN10_SCALED = 25984;

initial begin
    // bin = 0 ~ 255
    for (i = 0; i < 256; i = i + 1) begin
        // 10*ln(10+i)*256 的近似
        // ln(10)=2.302585 → 10*ln(10)*256 ≈ 5894
        log_lut[i] = integer'( (20.0 * $ln(160.0 + i)) * 256.0 - LN10_SCALED);
    end
end



always @(posedge clk) begin
    if (!resetn) begin
        fft_we       <= 1'b0;
        fft_addr     <= 8'd0;
        fft_data     <= 16'd0;
        process_addr <= 8'd0;
        write_done   <= 1'b0;
        start_skip   <= 1'b1;
        
        stage1_valid <= 1'b0;
        stage2_valid <= 1'b0;
        stage3_valid <= 1'b0;
        
        s1_mag       <= 16'd0;
        s1_addr      <= 8'd0;
        s1_prev_mag  <= 16'd0;
        s2_filt_mag  <= 16'd0;
        s2_addr      <= 8'd0;
        s3_weighted_mag <= 16'd0;
        s3_filt_mag  <= 16'd0;
        s3_addr      <= 8'd0;
        
    end else begin
        
        fft_we <= 1'b0;
        
        // ===============================================
        // 跳过 DC 分量（第一个 mag_valid）
        // ===============================================
        if (mag_valid && start_skip) begin
            start_skip <= 1'b0;
        end
        
        // ===============================================
        // Stage 1: 数据采集
        // 当 mag_valid 有效且不在跳过/完成状态时：
        // 1. 锁存当前 magnitude 和 process_addr
        // 2. 读取 RAM 中对应地址的历史值
        // ===============================================
        stage1_valid <= mag_valid && !write_done && !start_skip;
        
        if (mag_valid && !write_done && !start_skip) begin
            s1_mag      <= magnitude;                      // 锁存当前幅值
            s1_addr     <= process_addr;                   // 锁存当前地址
            s1_prev_mag <= prev_frame_mag[process_addr];   // 读历史值
            
            // 判断是否处理完所有 bin
            if (process_addr == max_addr) begin
                write_done <= 1'b1;
            end else begin
                process_addr <= process_addr + 1'b1;       // 地址递增
            end
        end
        
        // ===============================================
        // Stage 2: IIR 滤波计算
        // 使用 Stage1 锁存的数据进行计算
        // ===============================================
        stage2_valid <= stage1_valid;
        
        if (stage1_valid) begin
            // IIR 公式: y[n] = y[n-1] - y[n-1]/8 + x[n]/8
            s2_filt_mag <= s1_prev_mag 
                          - (s1_prev_mag >> IIR_SHIFT) 
                          + (s1_mag >> IIR_SHIFT);
            s2_addr     <= s1_addr;                        // 地址传递
        end
        
        // ===============================================
        // Stage 3: 频率加权 (10*ln(index))
        // ===============================================
        stage3_valid <= stage2_valid;
        
        if (stage2_valid) begin
                // 32位乘法，然后右移8位
                mult_tmp <= (s2_filt_mag - 16'd15 ) * log_lut[s2_addr];
                s3_weighted_mag <= s2_filt_mag;

            s3_filt_mag <= s2_filt_mag;  // 传递未加权的值
            s3_addr     <= s2_addr;
        end
        
        // ===============================================
        // Stage 4: 写回结果
        // 1. 输出到 FFT 接口（加权后的值）
        // 2. 更新 RAM 中的历史值（未加权的滤波值）
        // ===============================================
        if (stage3_valid) begin
            fft_we   <= 1'b1;
            fft_addr <= s3_addr;
            fft_data <= s3_weighted_mag;  // 输出加权后的值
            
            // 更新历史值 RAM（存储未加权的滤波值，用于下一帧IIR）
            prev_frame_mag[s3_addr] <= s3_filt_mag;
        end
        
        // ===============================================
        // 帧结束复位
        // ===============================================
        if (mag_last) begin
            process_addr <= 8'd0;
            write_done   <= 1'b0;
            start_skip   <= 1'b1;
            stage1_valid <= 1'b0;
            stage2_valid <= 1'b0;
            stage3_valid <= 1'b0;
        end
    end
end
endmodule