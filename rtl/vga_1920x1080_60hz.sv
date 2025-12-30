//==========================================================
// vga_dynamic.v
// VGA输出时序控制器 
// 带一个测试灰阶画面
// 支持两种分辨率
// 1080p60 (148.5 MHz)  /  720p30 (37.125 MHz)
// mode_sel = 1 -> 1080p60
// mode_sel = 0 -> 720p30
//==========================================================

module vga_dynamic (
    input  wire        clk_148m,     // 1080p pixel clk
    input  wire        clk_37m,      // 720p pixel clk
    input  wire        resetn,

    input  wire        mode_sel,     // 0=720p30  , 1=1080p60

    input  wire [3:0]  in_r,
    input  wire [3:0]  in_g,
    input  wire [3:0]  in_b,
    input  wire        use_input_pixel,

    output reg         hsync_n,
    output reg         vsync_n,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,

    output wire        visible,
    output wire [11:0] x,
    output wire [10:0] y
);

// ---------------------------------------------------------
// 使用选定的像素时钟 
// ---------------------------------------------------------
wire pix_clk = mode_sel ? clk_148m : clk_37m;

// ---------------------------------------------------------
// 两种模式的参数
// ---------------------------------------------------------

// 1080p60 timing
localparam H_VISIBLE_1080 = 1920;
localparam H_FP_1080      = 88;
localparam H_SYNC_1080    = 44;
localparam H_BP_1080      = 148;
localparam H_TOTAL_1080   = 2200;

localparam V_VISIBLE_1080 = 1080;
localparam V_FP_1080      = 4;
localparam V_SYNC_1080    = 5;
localparam V_BP_1080      = 36;
localparam V_TOTAL_1080   = 1125;

// 720p30 timing
localparam H_VISIBLE_720 = 1280;
localparam H_FP_720      = 110;
localparam H_SYNC_720    = 40;
localparam H_BP_720      = 220;
localparam H_TOTAL_720   = 1650;

localparam V_VISIBLE_720 = 720;
localparam V_FP_720      = 5;
localparam V_SYNC_720    = 5;
localparam V_BP_720      = 20;
localparam V_TOTAL_720   = 750;


// ---------------------------------------------------------
// 自动选择 resolution 参数
// ---------------------------------------------------------
wire [11:0] H_VISIBLE  = mode_sel ? H_VISIBLE_1080 : H_VISIBLE_720;
wire [11:0] H_FP       = mode_sel ? H_FP_1080      : H_FP_720;
wire [11:0] H_SYNC     = mode_sel ? H_SYNC_1080    : H_SYNC_720;
wire [11:0] H_BP       = mode_sel ? H_BP_1080      : H_BP_720;
wire [11:0] H_TOTAL    = mode_sel ? H_TOTAL_1080   : H_TOTAL_720;

wire [10:0] V_VISIBLE  = mode_sel ? V_VISIBLE_1080 : V_VISIBLE_720;
wire [10:0] V_FP       = mode_sel ? V_FP_1080      : V_FP_720;
wire [10:0] V_SYNC     = mode_sel ? V_SYNC_1080    : V_SYNC_720;
wire [10:0] V_BP       = mode_sel ? V_BP_1080      : V_BP_720;
wire [10:0] V_TOTAL    = mode_sel ? V_TOTAL_1080   : V_TOTAL_720;


// ---------------------------------------------------------
// Counters
// ---------------------------------------------------------
reg [11:0] hcnt;
reg [10:0] vcnt;

assign x = hcnt;
assign y = vcnt;

assign visible = (hcnt < H_VISIBLE) & (vcnt < V_VISIBLE);


// ---------------------------------------------------------
// HSYNC / VSYNC (negative)
// ---------------------------------------------------------
wire hsync_active =
    (hcnt >= (H_VISIBLE + H_FP)) &&
    (hcnt <  (H_VISIBLE + H_FP + H_SYNC));

wire vsync_active =
    (vcnt >= (V_VISIBLE + V_FP)) &&
    (vcnt <  (V_VISIBLE + V_FP + V_SYNC));


// ---------------------------------------------------------
// Counter update
// ---------------------------------------------------------
always @(posedge pix_clk or negedge resetn) begin
    if (!resetn) begin
        hcnt <= 0;
        vcnt <= 0;
    end else begin
        if (hcnt == H_TOTAL - 1) begin
            hcnt <= 0;
            if (vcnt == V_TOTAL - 1)
                vcnt <= 0;
            else
                vcnt <= vcnt + 1;
        end else begin
            hcnt <= hcnt + 1;
        end
    end
end


// ---------------------------------------------------------
// Sync output
// ---------------------------------------------------------
always @(posedge pix_clk or negedge resetn) begin
    if (!resetn) begin
        hsync_n <= 1'b1;
        vsync_n <= 1'b1;
    end else begin
        hsync_n <= ~hsync_active;
        vsync_n <= ~vsync_active;
    end
end


// ---------------------------------------------------------
// Pixel output
// ---------------------------------------------------------
always @(posedge pix_clk or negedge resetn) begin
    if (!resetn) begin
        vga_r <= 0;
        vga_g <= 0;
        vga_b <= 0;
    end else begin
        if (visible) begin
            if (use_input_pixel) begin
                vga_r <= in_r;
                vga_g <= in_g;
                vga_b <= in_b;
            end else begin
                // default gradient
                vga_r <= x[7:4];
                vga_g <= x[7:4];
                vga_b <= x[7:4];
            end
        end else begin
            vga_r <= 0;
            vga_g <= 0;
            vga_b <= 0;
        end
    end
end

endmodule
