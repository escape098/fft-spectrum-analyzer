// ============================================================
// bar_render_pixel_sync.v  
// 画面渲染，包括显示柱状图，原始波形，频率，配置等
// 实时渲染，无完整缓冲帧，采用流水线降低时序压力
// ============================================================
`timescale 1ns/1ps

module bar_render_pixel_sync(
    input  wire        pix_clk_720,
    input  wire        pix_clk_1080,
    input  wire        mode_sel,
    input  wire        resetn,

    input  wire        visible,
    input  wire [11:0] x,
    input  wire [10:0] y,

    input  wire [9:0]  fft_npoint,     // 128, 256, 512

    output wire [8:0]  ram_addr,
    input  wire [15:0] ram_dout,

    output reg  [3:0]  out_r,
    output reg  [3:0]  out_g,
    output reg  [3:0]  out_b,

    input  wire [7:0]  note_ascii1,
    input  wire [7:0]  note_ascii2,
    input  wire [7:0]  note_octave,
    
    // 新增：频率数字输入数组 (5位BCD码)
    input  wire [3:0]  digit [4:0],
    
    // 新增：Auto Range 开关状态
    input  wire        auto_range,      // 0: OFF, 1: ON
    
    // 新增：波形内存接口
    output wire [10:0] wave_buf_addr,   // 1920个点需要11位地址
    input  wire signed [15:0] wave_buf_dout  // 有符号16位波形数据
);

    wire pix_clk = mode_sel ? pix_clk_1080 : pix_clk_720;
    wire [11:0] screen_width  = mode_sel ? 1920 : 1280;
    wire [10:0] screen_height = mode_sel ? 1080 : 720;

    // compute bin width
    localparam integer B512_1080 = 9;
    localparam integer B512_720  = 6;

    wire [11:0] BIN_WIDTH =
        mode_sel ?
            (fft_npoint==512 ? B512_1080 :
             fft_npoint==256 ? (B512_1080<<1) :
                               (B512_1080<<2))
        :
            (fft_npoint==512 ? B512_720 :
             fft_npoint==256 ? (B512_720<<1) :
                               (B512_720<<2));

    assign ram_addr = x / BIN_WIDTH;

    // =============================
    //  延迟流水线（优化时序关键）
    // =============================
    // 增加流水线阶段，分解复杂组合逻辑
    reg [15:0] mag_d1, mag_d2;
    reg        vis_d1, vis_d2, vis_d3;
    reg [11:0] x_d1, x_d2, x_d3, x_d4;
    reg [10:0] y_d1, y_d2, y_d3, y_d4;
    reg [10:0] h_d1, h_d2, h_d3;
    reg [10:0] bar_height_d1, bar_height_d2;

    always @(posedge pix_clk) begin
        if(!resetn) begin
            mag_d1 <= 0; mag_d2 <= 0;
            vis_d1 <= 0; vis_d2 <= 0; vis_d3 <= 0;
            x_d1 <= 0; x_d2 <= 0; x_d3 <= 0; x_d4 <= 0;
            y_d1 <= 0; y_d2 <= 0; y_d3 <= 0; y_d4 <= 0;
            h_d1 <= 1080; h_d2 <= 1080; h_d3 <= 1080;
            bar_height_d1 <= 0; bar_height_d2 <= 0;
        end else begin
            // 第一阶段
            mag_d1 <= ram_dout;
            vis_d1 <= visible;
            x_d1 <= x;
            y_d1 <= y;
            h_d1 <= screen_height;
            
            // 第二阶段
            mag_d2 <= mag_d1;
            vis_d2 <= vis_d1;
            x_d2 <= x_d1;
            y_d2 <= y_d1;
            h_d2 <= h_d1;
            bar_height_d1 <= mag_d1[15:5];  // 提前计算柱状图高度
            
            // 第三阶段
            vis_d3 <= vis_d2;
            x_d3 <= x_d2;
            y_d3 <= y_d2;
            h_d3 <= h_d2;
            bar_height_d2 <= bar_height_d1;
            
            // 第四阶段（用于最终显示）
            x_d4 <= x_d3;
            y_d4 <= y_d3;
        end
    end

    // =============================
    //  参数定义
    // =============================
    localparam LARGE_CHAR_W = 64;
    localparam LARGE_CHAR_H = 128;
    localparam NOTE_CHARS = 3;
    localparam FREQ_CHARS = 7;
    
    localparam SMALL_CHAR_W = 32;
    localparam SMALL_CHAR_H = 64;
    localparam MENU_CHARS = 14;
    localparam BIN_CHARS = 7;
    
    // 波形显示参数
    localparam WAVE_AREA_H = 512;      // 512像素高度
    localparam WAVE_SAMPLES = 1920;
    
    // 区域计算
    localparam TOTAL_FREQ_W = LARGE_CHAR_W * FREQ_CHARS;
    localparam TOTAL_NOTE_W = LARGE_CHAR_W * NOTE_CHARS;
    localparam TOTAL_MENU_W = SMALL_CHAR_W * MENU_CHARS;
    localparam TOTAL_BIN_W  = SMALL_CHAR_W * BIN_CHARS;
    
    // 显示位置
    wire [11:0] freq_x0 = (screen_width > TOTAL_FREQ_W) ? ((screen_width - TOTAL_FREQ_W)>>1) : 0;
    wire [10:0] freq_y0 = 0;
    
    wire [11:0] note_x0 = (screen_width > TOTAL_NOTE_W) ? ((screen_width - TOTAL_NOTE_W)>>1) : 0;
    wire [10:0] note_y0 = LARGE_CHAR_H;
    
    wire [10:0] wave_y0 = note_y0 + LARGE_CHAR_H;
    wire [10:0] wave_y1 = wave_y0 + WAVE_AREA_H;
    
    wire [11:0] menu_x0 = screen_width - TOTAL_MENU_W - SMALL_CHAR_W;
    wire [10:0] menu_y0 = 0;
    
    wire [11:0] bin_x0 = screen_width - TOTAL_BIN_W - SMALL_CHAR_W;
    wire [10:0] bin_y0 = SMALL_CHAR_H;
    
    // =============================
    //  波形内存地址生成
    // =============================
    assign wave_buf_addr = (x < WAVE_SAMPLES) ? x[10:0] : 11'd0;
    
    // =============================
    //  波形数据处理流水线（优化时序）
    // =============================
    // 增加更多流水线阶段
    reg signed [15:0] wave_sample_d1, wave_sample_d2, wave_sample_d3;
    reg [10:0] wave_addr_d1, wave_addr_d2, wave_addr_d3;
    
    always @(posedge pix_clk) begin
        if(!resetn) begin
            wave_sample_d1 <= 0; wave_sample_d2 <= 0; wave_sample_d3 <= 0;
            wave_addr_d1 <= 0; wave_addr_d2 <= 0; wave_addr_d3 <= 0;
        end else begin
            // 第一阶段
            wave_sample_d1 <= wave_buf_dout;
            wave_addr_d1 <= wave_buf_addr;
            
            // 第二阶段
            wave_sample_d2 <= wave_sample_d1;
            wave_addr_d2 <= wave_addr_d1;
            
            // 第三阶段
            wave_sample_d3 <= wave_sample_d2;
            wave_addr_d3 <= wave_addr_d2;
        end
    end
    
    // =============================
    //  提前计算柱状图高度（优化关键路径）
    // =============================
    reg [10:0] adjusted_bar_height_reg;
    
    always @(posedge pix_clk) begin
        if(!resetn) begin
            adjusted_bar_height_reg <= 0;
        end else begin
            // 提前计算，避免在显示时计算
            if (auto_range) begin
                // 使用中间变量避免长组合链
                reg [11:0] temp_height;  // 使用11位避免溢出
                temp_height = {1'b0, bar_height_d2} << 1;  // x2
                
                if (temp_height > h_d3) begin
                    adjusted_bar_height_reg <= h_d3;
                end else begin
                    adjusted_bar_height_reg <= temp_height[10:0];
                end
            end else begin
                adjusted_bar_height_reg <= bar_height_d2;
            end
        end
    end
    
    // =============================
    //  波形坐标计算流水线（优化时序）
    // =============================
    // 阶段1：缩放计算
    reg signed [15:0] wave_scaled_reg;
    
    always @(posedge pix_clk) begin
        if(!resetn) begin
            wave_scaled_reg <= 0;
        end else begin
            wave_scaled_reg <= wave_sample_d3 >>> 4;  // 右移5位
        end
    end
    
    // 阶段2：偏移计算
    reg [10:0] wave_offset_abs_reg;
    reg wave_is_negative_reg;
    
    always @(posedge pix_clk) begin
        if(!resetn) begin
            wave_offset_abs_reg <= 0;
            wave_is_negative_reg <= 0;
        end else begin
            // 计算绝对值和符号
            if (wave_scaled_reg[15]) begin  // 负数
                wave_offset_abs_reg <= (~wave_scaled_reg[10:0] + 1);  // 取绝对值
                wave_is_negative_reg <= 1'b1;
            end else begin  // 正数
                wave_offset_abs_reg <= wave_scaled_reg[10:0];
                wave_is_negative_reg <= 1'b0;
            end
        end
    end
    
    // 阶段3：最终Y坐标计算
    reg [10:0] wave_screen_y_reg;
    reg [10:0] wave_y_center_reg;
    
    always @(posedge pix_clk) begin
        if(!resetn) begin
            wave_screen_y_reg <= 0;
            wave_y_center_reg <= 0;
        end else begin
            // 计算中心位置（0线）
            wave_y_center_reg <= wave_y0 + (WAVE_AREA_H >> 1);  // wave_y0 + 256
            
            // 计算最终Y坐标
            if (wave_is_negative_reg) begin
                wave_screen_y_reg <= wave_y_center_reg - wave_offset_abs_reg;
            end else begin
                wave_screen_y_reg <= wave_y_center_reg + wave_offset_abs_reg;
            end
            
            // 边界检查
            if (wave_screen_y_reg < wave_y0) begin
                wave_screen_y_reg <= wave_y0;
            end else if (wave_screen_y_reg >= wave_y1) begin
                wave_screen_y_reg <= wave_y1 - 1;
            end
        end
    end
    
    // 阶段4：波形像素判断
    reg is_wave_pixel_reg;
    
    always @(posedge pix_clk) begin
        if(!resetn) begin
            is_wave_pixel_reg <= 0;
        end else begin
            // 判断当前像素是否在波形线上（±1像素）
            if ((y_d3 >= wave_screen_y_reg - 1) && 
                (y_d3 <= wave_screen_y_reg + 1) &&
                (wave_addr_d3 < WAVE_SAMPLES) &&
                (y_d3 >= wave_y0) && 
                (y_d3 < wave_y1)) begin
                is_wave_pixel_reg <= 1'b1;
            end else begin
                is_wave_pixel_reg <= 1'b0;
            end
        end
    end
    
    // =============================
    //  显示区域判断（流水线化）
    // =============================
    // 使用x_d3/y_d3进行区域判断（与波形数据同步）
    wire in_freq_area_d3 =
        (y_d3 >= freq_y0) &&
        (y_d3 <  freq_y0 + LARGE_CHAR_H) &&
        (x_d3 >= freq_x0) &&
        (x_d3 <  freq_x0 + TOTAL_FREQ_W);

    wire in_note_area_d3 =
        (y_d3 >= note_y0) &&
        (y_d3 <  note_y0 + LARGE_CHAR_H) &&
        (x_d3 >= note_x0) &&
        (x_d3 <  note_x0 + TOTAL_NOTE_W);

    wire in_menu_area_d3 =
        (y_d3 >= menu_y0) &&
        (y_d3 <  menu_y0 + SMALL_CHAR_H) &&
        (x_d3 >= menu_x0) &&
        (x_d3 <  menu_x0 + TOTAL_MENU_W);

    wire in_bin_area_d3 =
        (y_d3 >= bin_y0) &&
        (y_d3 <  bin_y0 + SMALL_CHAR_H) &&
        (x_d3 >= bin_x0) &&
        (x_d3 <  bin_x0 + TOTAL_BIN_W);
    
    // =============================
    //  字符选择和坐标计算（使用x_d4/y_d4）
    // =============================
    wire is_freq_display_d4 = in_freq_area_d3;  // 注意：区域用_d3，字符用_d4
    wire is_note_display_d4 = in_note_area_d3;
    wire is_menu_display_d4 = in_menu_area_d3;
    wire is_bin_display_d4 = in_bin_area_d3;
    
    // 计算字符槽位（使用x_d4）
    wire [3:0] freq_char_slot = is_freq_display_d4 ? ((x_d4 - freq_x0) / LARGE_CHAR_W) : 4'd0;
    wire [3:0] note_char_slot = is_note_display_d4 ? ((x_d4 - note_x0) / LARGE_CHAR_W) : 4'd0;
    wire [3:0] menu_char_slot = is_menu_display_d4 ? ((x_d4 - menu_x0) / SMALL_CHAR_W) : 4'd0;
    wire [3:0] bin_char_slot = is_bin_display_d4 ? ((x_d4 - bin_x0) / SMALL_CHAR_W) : 4'd0;

    // 计算字符内像素坐标
    wire [6:0] large_glyph_x = 
        is_freq_display_d4 ? ((x_d4 - freq_x0) % LARGE_CHAR_W) :
        is_note_display_d4 ? ((x_d4 - note_x0) % LARGE_CHAR_W) : 7'd0;
        
    wire [5:0] small_glyph_x = 
        is_menu_display_d4 ? ((x_d4 - menu_x0) % SMALL_CHAR_W) :
        is_bin_display_d4 ? ((x_d4 - bin_x0) % SMALL_CHAR_W) : 6'd0;

    // 计算字符内Y坐标（使用y_d4）
    wire [10:0] freq_y_offset = is_freq_display_d4 ? (y_d4 - freq_y0) : 11'd0;
    wire [10:0] note_y_offset = is_note_display_d4 ? (y_d4 - note_y0) : 11'd0;
    wire [10:0] menu_y_offset = is_menu_display_d4 ? (y_d4 - menu_y0) : 11'd0;
    wire [10:0] bin_y_offset = is_bin_display_d4 ? (y_d4 - bin_y0) : 11'd0;
    
    wire [6:0] large_glyph_y = 
        is_freq_display_d4 ? freq_y_offset[6:0] :
        is_note_display_d4 ? note_y_offset[6:0] : 7'd0;
        
    wire [5:0] small_glyph_y = 
        is_menu_display_d4 ? menu_y_offset[5:0] :
        is_bin_display_d4 ? bin_y_offset[5:0] : 6'd0;

    // 字符选择逻辑
    reg [7:0] large_glyph_ch;
    reg [7:0] small_glyph_ch;
    
    wire [2:0] first_nonzero_pos = 
        (digit[4] != 0) ? 3'd0 : 
        (digit[3] != 0) ? 3'd1 : 
        (digit[2] != 0) ? 3'd2 : 
        (digit[1] != 0) ? 3'd3 : 3'd4;

    // FFT点数转数字
    wire [3:0] fft_hundreds = fft_npoint[9] ? 4'd5 : (fft_npoint[8] ? 4'd2 : 4'd1);
    wire [3:0] fft_tens = fft_npoint[9] ? 4'd1 : (fft_npoint[8] ? 4'd5 : 4'd2);
    wire [3:0] fft_ones = fft_npoint[9] ? 4'd2 : (fft_npoint[8] ? 4'd6 : 4'd8);

    // 大字符显示逻辑
    always @(*) begin
        large_glyph_ch = 8'h20;
        
        if (is_freq_display_d4) begin
            if (freq_char_slot < 5) begin
                if (freq_char_slot < first_nonzero_pos) begin
                    large_glyph_ch = 8'h20;
                end else begin
                    case(freq_char_slot)
                        4'd0: large_glyph_ch = {4'h3, digit[4]};
                        4'd1: large_glyph_ch = {4'h3, digit[3]};
                        4'd2: large_glyph_ch = {4'h3, digit[2]};
                        4'd3: large_glyph_ch = {4'h3, digit[1]};
                        4'd4: large_glyph_ch = {4'h3, digit[0]};
                        default: large_glyph_ch = 8'h20;
                    endcase
                end
            end else if (freq_char_slot == 5) begin
                large_glyph_ch = "H";
            end else if (freq_char_slot == 6) begin
                large_glyph_ch = "z";
            end
        end else if (is_note_display_d4) begin
            case(note_char_slot[1:0])
                2'd0: large_glyph_ch = note_ascii1;
                2'd1: large_glyph_ch = note_ascii2;
                2'd2: large_glyph_ch = note_octave;
                default: large_glyph_ch = 8'h20;
            endcase
        end
    end

    // 小字符显示逻辑
    always @(*) begin
        small_glyph_ch = 8'h20;
        
        if (is_menu_display_d4) begin
            case(menu_char_slot)
                4'd0: small_glyph_ch = "A";
                4'd1: small_glyph_ch = "u";
                4'd2: small_glyph_ch = "t";
                4'd3: small_glyph_ch = "o";
                4'd4: small_glyph_ch = " ";
                4'd5: small_glyph_ch = "R";
                4'd6: small_glyph_ch = "a";
                4'd7: small_glyph_ch = "n";
                4'd8: small_glyph_ch = "g";
                4'd9: small_glyph_ch = "e";
                4'd10: small_glyph_ch = " ";
                4'd11: small_glyph_ch = (auto_range) ? "O" : "O";
                4'd12: small_glyph_ch = (auto_range) ? "N" : "F";
                4'd13: small_glyph_ch = (!auto_range) ? "F" : " ";
                default: small_glyph_ch = 8'h20;
            endcase
        end else if (is_bin_display_d4) begin
            case(bin_char_slot)
                4'd0: small_glyph_ch = "B";
                4'd1: small_glyph_ch = "i";
                4'd2: small_glyph_ch = "n";
                4'd3: small_glyph_ch = " ";
                4'd4: small_glyph_ch = {4'h3, fft_hundreds};
                4'd5: small_glyph_ch = {4'h3, fft_tens};
                4'd6: small_glyph_ch = {4'h3, fft_ones};
                default: small_glyph_ch = 8'h20;
            endcase
        end
    end

    // =============================
    //  字符模块实例化
    // =============================
    wire large_glyph_pixel;
    glyph_64x128_from_8x16 large_glyph_u(
        .clk(pix_clk),
        .resetn(resetn),
        .ch(large_glyph_ch),
        .px_x(large_glyph_x),
        .px_y(large_glyph_y),
        .pixel_on(large_glyph_pixel)
    );
    
    wire small_glyph_pixel;
    glyph_32x64_from_8x16 small_glyph_u(
        .clk(pix_clk),
        .resetn(resetn),
        .ch(small_glyph_ch),
        .px_x(small_glyph_x),
        .px_y(small_glyph_y),
        .pixel_on(small_glyph_pixel)
    );

    // =============================
    //  最终像素绘制（优化后）
    // =============================
    
    /*wire [7:0] gx = x[10:3];   // 横向：4 像素一段 + 256 级
    wire [7:0] gy = y[10:3];   // 纵向：4 像素一段 + 256 级
    wire [7:4] r = gx[7:4]-gy[7:4];
    wire [7:4] g = gx[7:4];
    wire [7:4] b = gy[7:4];8*/
    wire [7:0] xg = x[10:3];   // 1920 / 16 ≈ 120，但会自然铺满 0~255
    wire [2:0] zone = xg[7:5];   // 8 个区段
    wire [4:0] t    = xg[4:0];   // 区段内渐变
    
    reg [3:0] r, g, b;

always @(*) begin
    case (zone)
        3'd0: begin // 红 -> 黄
            r = 4'hF;
            g = t[4:1];
            b = 4'h0;
        end
        3'd1: begin // 黄 -> 绿
            r = ~t[4:1];
            g = 4'hF;
            b = 4'h0;
        end
        3'd2: begin // 绿 -> 青
            r = 4'h0;
            g = 4'hF;
            b = t[4:1];
        end
        3'd3: begin // 青 -> 蓝
            r = 4'h0;
            g = ~t[4:1];
            b = 4'hF;
        end
        3'd4: begin // 蓝 -> 紫
            r = t[4:1];
            g = 4'h0;
            b = 4'hF;
        end
        3'd5: begin // 紫 -> 红
            r = 4'hF;
            g = 4'h0;
            b = ~t[4:1];
        end
        default: begin // 回环红
            r = 4'hF;
            g = 4'h0;
            b = 4'h0;
        end
    endcase
end

    always @(posedge pix_clk) begin
        if(!resetn) begin
            out_r <= 0;
            out_g <= 0;
            out_b <= 0;
        end else begin
            // 默认背景：黑色
            out_r <= 0; out_g <= 0; out_b <= 0;

            // 1. 白色频谱柱（使用提前计算的高度）
            if(vis_d3 && (y_d3 >= (h_d3 - adjusted_bar_height_reg))) begin
                out_r <= r;
                out_g <= g;
                out_b <= b;
            end
            
            // 2. 绿色波形显示
            if(is_wave_pixel_reg) begin
                out_r <= 4'h0;
                out_g <= 4'hF;
                out_b <= 4'h0;
            end

            // 3. 红色频率显示
            if(in_freq_area_d3 && large_glyph_pixel) begin
                out_r <= 4'hF;
                out_g <= 4'h0;
                out_b <= 4'h0;
            end
            
            // 4. 蓝色音名显示
            if(in_note_area_d3 && large_glyph_pixel) begin
                out_r <= 4'h0;
                out_g <= 4'h0;
                out_b <= 4'hF;
            end
            
            // 5. 橙色菜单显示
            if(in_menu_area_d3 && small_glyph_pixel) begin
                if (menu_char_slot <= 9) begin
                    out_r <= 4'hF;
                    out_g <= 4'h8;
                    out_b <= 4'h0;
                end else if (menu_char_slot >= 11) begin
                    if (auto_range) begin
                        out_r <= 4'h0;
                        out_g <= 4'hF;
                        out_b <= 4'h0;
                    end else begin
                        out_r <= 4'hF;
                        out_g <= 4'h0;
                        out_b <= 4'h0;
                    end
                end
            end
            
            // 6. Bin显示
            if(in_bin_area_d3 && small_glyph_pixel) begin
                if (bin_char_slot <= 2) begin
                    out_r <= 4'hF;
                    out_g <= 4'h8;
                    out_b <= 4'h0;
                end else if (bin_char_slot >= 4) begin
                    out_r <= 4'h0;
                    out_g <= 4'h0;
                    out_b <= 4'hF;
                end
            end
        end
    end

endmodule
