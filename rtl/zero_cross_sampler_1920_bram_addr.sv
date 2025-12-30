// ===================================================================
// zero_cross_sampler.v
// 过0上升检测，循环采样1920个原始数据点写入RAM，给显示渲染模块用
// ===================================================================
`timescale 1ns/1ps

module zero_cross_sampler_1920_bram_addr #(
    parameter integer DATA_WIDTH = 16,
    parameter integer BUF_LEN    = 1920
)(
    // 写侧（音频输入）
    input  wire                  wr_clk,
    input  wire signed [DATA_WIDTH-1:0] din,  // 有符号音频数据
    input  wire                  din_valid,

    // 读侧（任意地址访问）
    input  wire                  rd_clk,
    input  wire [$clog2(BUF_LEN)-1:0] rd_addr,        // 任意地址
    output reg  [DATA_WIDTH-1:0] dout,

    // 一帧采集完成标志（跨域同步）- 现在每帧都完成
    output wire                  buf_ready//
);

    // 简化：去掉所有过零检测逻辑，不断循环写入
    reg [$clog2(BUF_LEN)-1:0] wr_ptr = 0;      // 写指针，从0开始
    
    // BRAM 写口寄存器
    reg                        wr_en_reg;
    reg [$clog2(BUF_LEN)-1:0]  wr_addr_reg;
    reg [DATA_WIDTH-1:0]       wr_data_reg;

    // 写完成标志（写域）- 现在每写满1920个点就置位一次
    reg frame_done_wr;
    reg [$clog2(BUF_LEN)-1:0] write_counter;  // 计数写入的样本数
    
    // 写逻辑：不断循环写入
    always @(posedge wr_clk) begin
        // 默认值
        wr_en_reg <= 1'b0;
        frame_done_wr <= 1'b0;
        
        if (din_valid) begin
            // 写入当前数据
            wr_en_reg <= 1'b1;
            wr_addr_reg <= wr_ptr;
            wr_data_reg <= din;
            
            // 更新写指针
            if (wr_ptr == BUF_LEN - 1) begin
                wr_ptr <= 0;
                // 写满一帧（1920个点）
                frame_done_wr <= 1'b1;
            end else begin
                wr_ptr <= wr_ptr + 1;
            end
            
            // 计数写入的样本数（用于调试）
            if (write_counter == BUF_LEN - 1) begin
                write_counter <= 0;
            end else begin
                write_counter <= write_counter + 1;
            end
        end
    end

    // 暴露内部写信号给BRAM实例
    wire bram_wea  = wr_en_reg;
    wire [($clog2(BUF_LEN)-1):0] bram_addra = wr_addr_reg;
    wire [DATA_WIDTH-1:0] bram_dina = wr_data_reg;

    // ============================================================
    // BRAM：XPM 双时钟 SDP RAM
    // ============================================================
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A   ($clog2(BUF_LEN)),
        .ADDR_WIDTH_B   ($clog2(BUF_LEN)),
        .MEMORY_SIZE    (BUF_LEN * DATA_WIDTH),
        .MEMORY_PRIMITIVE("block"),
        .READ_DATA_WIDTH_B(DATA_WIDTH),
        .WRITE_DATA_WIDTH_A(DATA_WIDTH),
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH),
        .READ_LATENCY_B (1),
        .CLOCKING_MODE("independent_clock")
    ) sample_bram (
        // 写端 A
        .clka   (wr_clk),
        .ena    (1'b1),
        .wea    (bram_wea),
        .addra  (bram_addra),
        .dina   (bram_dina),

        // 读端 B
        .clkb   (rd_clk),
        .enb    (1'b1),
        .addrb  (rd_addr),
        .doutb  (dout)
    );

    // ============================================================
    // 跨时钟同步 frame_done_wr
    // ============================================================
    reg sync1, sync2;
    always @(posedge rd_clk) begin
        sync1 <= frame_done_wr;
        sync2 <= sync1;
    end
    assign buf_ready = sync2;

endmodule