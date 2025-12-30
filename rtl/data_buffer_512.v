// ===================================================================
// buffer_fft.v
// 为了fft计算稳定性，加入此跨时钟域缓冲区
// 支持缓冲 512/256/128 为一组的数据
// ===================================================================
module buffer_fft #(
    parameter RESET_PULSE_CYCLES = 32
)(
    input  wire        clk,
    input  wire        resetn,

    // 动态点数输入：128 / 256 / 512
    input  wire [9:0]  frame_size,    

    input  wire [15:0] din,
    input  wire        din_valid,
    output reg  [15:0] dout_real,
    output reg         dout_valid,
    output reg         dout_last,
    output reg         fft_reset_pulse
);

    reg [15:0] buffer [0:511];   
    reg [9:0]  write_ptr;
    reg [9:0]  read_ptr;
    reg        buffer_full;
    reg        output_active;
    reg [9:0]  output_count;
    reg [5:0]  reset_counter;
    reg        reset_done;

    always @(posedge clk) begin
        if (!resetn) begin
            write_ptr <= 0;
            buffer_full <= 1'b0;
            fft_reset_pulse <= 1'b0;
            reset_counter <= 0;
            reset_done <= 1'b0;
            dout_valid <= 1'b0;
            dout_last <= 1'b0;
            output_active <= 1'b0;
            read_ptr <= 0;
            output_count <= 0;
        end else begin

            // ===== 写入 =====
            if (din_valid) begin
                buffer[write_ptr] <= din;

                if (write_ptr == frame_size - 1) begin  
                    write_ptr <= 0;
                    buffer_full <= 1'b1;
                    fft_reset_pulse <= 1'b1;
                    reset_counter <= RESET_PULSE_CYCLES;
                    reset_done <= 1'b0;
                end else begin
                    write_ptr <= write_ptr + 1;
                end
            end


            // ===== reset 脉冲倒计时 =====
            if (reset_counter > 0) begin
                reset_counter <= reset_counter - 1;
                if (reset_counter == 1) begin
                    fft_reset_pulse <= 1'b0;
                    reset_done <= 1'b1;
                end
            end


            // ===== 开始输出 =====
            if (buffer_full && reset_done && !output_active) begin
                output_active <= 1'b1;
                read_ptr <= 0;
                output_count <= 0;
            end


            // ===== 输出 =====
            if (output_active) begin
                dout_valid <= 1'b1;
                dout_real <= buffer[read_ptr];

                if (output_count == frame_size - 1) begin   // ★★★ 动态点数
                    dout_last <= 1'b1;
                    output_active <= 1'b0;
                    buffer_full <= 1'b0;
                    output_count <= 0;
                end else begin
                    dout_last <= 1'b0;
                    read_ptr <= read_ptr + 1;
                    output_count <= output_count + 1;
                end
            end else begin
                dout_valid <= 1'b0;
                dout_last <= 1'b0;
            end
        end
    end

endmodule
