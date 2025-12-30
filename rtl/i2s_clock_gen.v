// ===================================================================
// i2s_clock_gen.v
// pcm1808模块驱动波形生成
// ===================================================================
module i2s_clock_gen (
    input  wire clk_100m,   // 100MHz 输入
    input  wire rst_n,      
    output wire mclk,       // 12.288 MHz
    output wire bck,        // 3.072 MHz
    output wire lrck        // 48 kHz
);

    // ----------------------
    // 1) Clock Wizard 输出 MCLK = 12.288GHz
    // ----------------------
    clk_wiz_mclk clk_wiz_inst (
        .clk_in1(clk_100m),
        .clk_out1(mclk),  
        .reset(~rst_n),
        .locked()
    );

    // ----------------------
    // 2) 分频得到 BCK = MCLK / 4 = 3.072 MHz
    // ----------------------
    reg [1:0] div4_cnt = 0;
    always @(posedge mclk or negedge rst_n) begin
        if(!rst_n)
            div4_cnt <= 0;
        else
            div4_cnt <= div4_cnt + 1;
    end
    assign bck = div4_cnt[1];

    // ----------------------
    // 3) LRCK = BCK / 64 = 48 kHz
    // ----------------------
    reg [5:0] div64_cnt = 0;
    always @(posedge bck or negedge rst_n) begin
        if(!rst_n)
            div64_cnt <= 0;
        else
            div64_cnt <= div64_cnt + 1;
    end
    assign lrck = div64_cnt[5];

endmodule