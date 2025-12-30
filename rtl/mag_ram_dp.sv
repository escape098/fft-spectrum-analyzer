// ===================================================================
// mag_ram_dp.v
// 双端口RAM，从fft封装模块存入幅值数据，给渲染柱状图时读取
// ===================================================================
module mag_ram_dp (
    // Port A: FFT 写
    input  wire        clk_a,
    input  wire [7:0]  addr_a,
    input  wire [15:0] din_a,
    input  wire        we_a,

    // Port B: VGA 读
    input  wire        clk_b,
    input  wire [7:0]  addr_b,
    output reg  [15:0] dout_b
);

    reg [15:0] mem [0:255];

    // 写端口 A
    always @(posedge clk_a) begin
        if (we_a)
            mem[addr_a] <= din_a;
    end

    // 读端口 B
    always @(posedge clk_b) begin
        dout_b <= mem[addr_b];
    end
endmodule
