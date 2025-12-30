// ===================================================================
// config_manager.v
// 统一实现按键切换各种模式
// ===================================================================
`timescale 1ns/1ps

module config_manager (
    // 时钟和复位
    input  wire        clk,           // 系统时钟
    input  wire        resetn,        // 系统复位
    
    // 按键输入
    input  wire        key0_edge,     // KEY0：VGA分辨率切换
    input  wire        key1_edge,     // KEY1：FFT点数切换
    input  wire        key2_edge,     // KEY2：自动量程切换
    input  wire        key3_edge,     // KEY3：保留（可用于其他功能）
    input  wire        key4_edge,     // KEY4：保留（可用于其他功能）
    
    // 配置输出
    output reg         video_mode,    // VGA分辨率模式：0=720p，1=1080p
    output reg [1:0]   fft_sel,       // FFT点数选择：00=128,01=256,10=512
    output wire [9:0]  frame_size,    // 实际FFT点数
    output reg         auto_range,    // 自动量程使能：0=关闭，1=开启
    output reg [23:0]  cfg_data_sel   // FFT配置数据
);

// FFT点数配置常量
localparam FRAME_SIZE_128 = 10'd128;
localparam FRAME_SIZE_256 = 10'd256;
localparam FRAME_SIZE_512 = 10'd512;

// FFT配置数据常量
localparam CONFIG_128 = 24'b100100000000000111;  // 128点配置
localparam CONFIG_256 = 24'b100100000000001000;  // 256点配置
localparam CONFIG_512 = 24'b100100000000001001;  // 512点配置

// 保留按键计数器
reg [7:0] key3_counter;  // KEY3按下次数计数
reg [7:0] key4_counter;  // KEY4按下次数计数

// VGA分辨率模式切换（KEY0控制）
// 0 = 720p (1280x720)
// 1 = 1080p (1920x1080)
always @(posedge clk) begin
    if (!resetn)
        video_mode <= 1'b1;           // 默认1080p模式
    else if (key0_edge)
        video_mode <= ~video_mode;    // 切换分辨率
end

// FFT点数选择（KEY1控制循环切换）
// 00 = 128点FFT
// 01 = 256点FFT
// 10 = 512点FFT
always @(posedge clk) begin
    if (!resetn)
        fft_sel <= 2'b10;                    // 默认512点
    else if (key1_edge) begin
        case (fft_sel)
            2'b00: fft_sel <= 2'b01;        // 128->256
            2'b01: fft_sel <= 2'b10;        // 256->512
            2'b10: fft_sel <= 2'b00;        // 512->128
            default: fft_sel <= 2'b10;
        endcase
    end
end

// 根据选择确定实际FFT点数
assign frame_size = (fft_sel == 2'b00) ? FRAME_SIZE_128 :      // 128点FFT
                   (fft_sel == 2'b01) ? FRAME_SIZE_256 :       // 256点FFT
                   FRAME_SIZE_512;                            // 512点FFT

// FFT配置数据（根据点数选择不同配置）
always @(*) begin
    case (fft_sel)
        2'd0: cfg_data_sel = CONFIG_128;  // 128点配置
        2'd1: cfg_data_sel = CONFIG_256;  // 256点配置
        2'd2: cfg_data_sel = CONFIG_512;  // 512点配置
        default: cfg_data_sel = CONFIG_512;
    endcase
end

// 自动量程切换（KEY2控制）
// 0 = 关闭自动量程（固定显示范围）
// 1 = 开启自动量程（根据信号强度自动调整）
always @(posedge clk) begin
    if (!resetn)
        auto_range <= 1'b0;                  // 默认关闭
    else if (key2_edge)
        auto_range <= ~auto_range;           // 切换状态
end

// KEY3计数器
always @(posedge clk) begin
    if (!resetn)
        key3_counter <= 8'd0;
    else if (key3_edge)
        key3_counter <= key3_counter + 8'd1;
end

// KEY4计数器
always @(posedge clk) begin
    if (!resetn)
        key4_counter <= 8'd0;
    else if (key4_edge)
        key4_counter <= key4_counter + 8'd1;
end

endmodule