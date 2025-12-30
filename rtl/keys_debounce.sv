// ===================================================================
// key_debounce.v
// 按键消抖，一共5个，实际用到3个，2个备用
// ===================================================================
module keys_debounce #(
    parameter integer STABLE_CNT = 100000       
)(
    input  wire clk,
    input  wire resetn,

    input  wire key0_raw,
    input  wire key1_raw,
    input  wire key2_raw,
    input  wire key3_raw,
    input  wire key4_raw,

    output reg  key0_edge,
    output reg  key1_edge,
    output reg  key2_edge,
    output reg  key3_edge,
    output reg  key4_edge,

    output reg  key0,
    output reg  key1,
    output reg  key2,
    output reg  key3,
    output reg  key4
);

    reg [31:0] c0, c1, c2, c3, c4;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            key0 <= 0; key1 <= 0; key2 <= 0; key3 <= 0; key4 <= 0;
            key0_edge <= 0; key1_edge <= 0; key2_edge <= 0; key3_edge <= 0; key4_edge <= 0;
            c0 <= 0; c1 <= 0; c2 <= 0; c3 <= 0; c4 <= 0;
        end else begin
            
            // ===== KEY0 =====
            key0_edge <= 0;
            if (key0_raw != key0) begin
                c0 <= c0 + 1;
                if (c0 >= STABLE_CNT) begin
                    key0 <= key0_raw;
                    key0_edge <= key0_raw;   // only on press
                    c0 <= 0;
                end
            end else begin
                c0 <= 0;
            end

            // ===== KEY1 =====
            key1_edge <= 0;
            if (key1_raw != key1) begin
                c1 <= c1 + 1;
                if (c1 >= STABLE_CNT) begin
                    key1 <= key1_raw;
                    key1_edge <= key1_raw;
                    c1 <= 0;
                end
            end else begin
                c1 <= 0;
            end

            // ===== KEY2 =====
            key2_edge <= 0;
            if (key2_raw != key2) begin
                c2 <= c2 + 1;
                if (c2 >= STABLE_CNT) begin
                    key2 <= key2_raw;
                    key2_edge <= key2_raw;
                    c2 <= 0;
                end
            end else begin
                c2 <= 0;
            end

            // ===== KEY3 =====
            key3_edge <= 0;
            if (key3_raw != key3) begin
                c3 <= c3 + 1;
                if (c3 >= STABLE_CNT) begin
                    key3 <= key3_raw;
                    key3_edge <= key3_raw;
                    c3 <= 0;
                end
            end else begin
                c3 <= 0;
            end

            // ===== KEY4 =====
            key4_edge <= 0;
            if (key4_raw != key4) begin
                c4 <= c4 + 1;
                if (c4 >= STABLE_CNT) begin
                    key4 <= key4_raw;
                    key4_edge <= key4_raw;
                    c4 <= 0;
                end
            end else begin
                c4 <= 0;
            end

        end
    end

endmodule
