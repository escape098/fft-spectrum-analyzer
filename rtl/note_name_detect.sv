// ===================================================================
// note_name_detect.v
// 音名查找匹配
// 边界[i] = sqrt(freq[i] * freq[i+1]) 的整数近似值
// 输出完整音名ASCII码
// ===================================================================
module note_name_detect (
    input  wire        clk,
    input  wire        resetn,

    input  wire [15:0] detected_freq,  // Hz（整数）
    input  wire        freq_valid,     // 上升沿表示当前 detected_freq 有效并要查找

    output reg  [7:0]  note_ascii1,    // 'A'..'G'
    output reg  [7:0]  note_ascii2,    // '#' or ' '
    output reg  [7:0]  note_octave     // '0'..'9'
);

    // =====================================================
    // 1) 频率边界表（121个边界，对应120个音调）
    // 边界[i] = sqrt(freq[i] * freq[i+1]) 的整数近似值
    // 边界[0]是C0以下，边界[120]是B9以上
    // =====================================================
    reg [15:0] freq_bound [0:120];
    initial begin
        // 边界表（几何平均值的整数近似，四舍五入）
        freq_bound[  0] =     14; // C0以下边界
        
        // C0 - B0 边界
        freq_bound[  1] =     16; freq_bound[  2] =     17; freq_bound[  3] =     18;
        freq_bound[  4] =     20; freq_bound[  5] =     21; freq_bound[  6] =     22;
        freq_bound[  7] =     23; freq_bound[  8] =     25; freq_bound[  9] =     26;
        freq_bound[ 10] =     28; freq_bound[ 11] =     29; freq_bound[ 12] =     32;
        
        // C1 - B1 边界
        freq_bound[ 13] =     34; freq_bound[ 14] =     36; freq_bound[ 15] =     38;
        freq_bound[ 16] =     40; freq_bound[ 17] =     42; freq_bound[ 18] =     45;
        freq_bound[ 19] =     47; freq_bound[ 20] =     50; freq_bound[ 21] =     53;
        freq_bound[ 22] =     56; freq_bound[ 23] =     59; freq_bound[ 24] =     63;
        
        // C2 - B2 边界
        freq_bound[ 25] =     67; freq_bound[ 26] =     71; freq_bound[ 27] =     75;
        freq_bound[ 28] =     80; freq_bound[ 29] =     84; freq_bound[ 30] =     89;
        freq_bound[ 31] =     95; freq_bound[ 32] =    101; freq_bound[ 33] =    107;
        freq_bound[ 34] =    113; freq_bound[ 35] =    120; freq_bound[ 36] =    127;
        
        // C3 - B3 边界
        freq_bound[ 37] =    135; freq_bound[ 38] =    143; freq_bound[ 39] =    151;
        freq_bound[ 40] =    160; freq_bound[ 41] =    170; freq_bound[ 42] =    180;
        freq_bound[ 43] =    190; freq_bound[ 44] =    202; freq_bound[ 45] =    214;
        freq_bound[ 46] =    226; freq_bound[ 47] =    240; freq_bound[ 48] =    254;
        
        // C4 - B4 边界 (A4=440Hz)
        freq_bound[ 49] =    269; freq_bound[ 50] =    285; freq_bound[ 51] =    302;
        freq_bound[ 52] =    320; freq_bound[ 53] =    339; freq_bound[ 54] =    359;
        freq_bound[ 55] =    381; freq_bound[ 56] =    403; freq_bound[ 57] =    427;
        freq_bound[ 58] =    453; freq_bound[ 59] =    480; freq_bound[ 60] =    508;
        
        // C5 - B5 边界
        freq_bound[ 61] =    539; freq_bound[ 62] =    570; freq_bound[ 63] =    604;
        freq_bound[ 64] =    640; freq_bound[ 65] =    678; freq_bound[ 66] =    718;
        freq_bound[ 67] =    761; freq_bound[ 68] =    806; freq_bound[ 69] =    854;
        freq_bound[ 70] =    905; freq_bound[ 71] =    959; freq_bound[ 72] =   1016;
        
        // C6 - B6 边界
        freq_bound[ 73] =   1077; freq_bound[ 74] =   1141; freq_bound[ 75] =   1209;
        freq_bound[ 76] =   1281; freq_bound[ 77] =   1357; freq_bound[ 78] =   1438;
        freq_bound[ 79] =   1523; freq_bound[ 80] =   1614; freq_bound[ 81] =   1709;
        freq_bound[ 82] =   1811; freq_bound[ 83] =   1919; freq_bound[ 84] =   2033;
        
        // C7 - B7 边界
        freq_bound[ 85] =   2154; freq_bound[ 86] =   2282; freq_bound[ 87] =   2418;
        freq_bound[ 88] =   2562; freq_bound[ 89] =   2715; freq_bound[ 90] =   2876;
        freq_bound[ 91] =   3047; freq_bound[ 92] =   3228; freq_bound[ 93] =   3419;
        freq_bound[ 94] =   3623; freq_bound[ 95] =   3838; freq_bound[ 96] =   4067;
        
        // C8 - B8 边界
        freq_bound[ 97] =   4308; freq_bound[ 98] =   4565; freq_bound[ 99] =   4837;
        freq_bound[100] =   5124; freq_bound[101] =   5429; freq_bound[102] =   5752;
        freq_bound[103] =   6094; freq_bound[104] =   6457; freq_bound[105] =   6841;
        freq_bound[106] =   7248; freq_bound[107] =   7679; freq_bound[108] =   8136;
        
        // C9 - B9 边界
        freq_bound[109] =   8620; freq_bound[110] =   9132; freq_bound[111] =   9675;
        freq_bound[112] =  10250; freq_bound[113] =  10860; freq_bound[114] =  11505;
        freq_bound[115] =  12190; freq_bound[116] =  12915; freq_bound[117] =  13683;
        freq_bound[118] =  14497; freq_bound[119] =  15359; freq_bound[120] =  23706;
    end

    // =====================================================
    // 2) 音名表
    // =====================================================
    reg [7:0] note_name1 [0:119]; // 'A'..'G' 字符
    reg [7:0] note_name2 [0:119]; // '#' 或 ' '
    integer ii; integer nn;
    initial begin
        nn = 0;
        for (ii = 0; ii < 10; ii = ii + 1) begin
            note_name1[nn] = "C"; note_name2[nn] = " "; nn = nn + 1;
            note_name1[nn] = "C"; note_name2[nn] = "#"; nn = nn + 1;
            note_name1[nn] = "D"; note_name2[nn] = " "; nn = nn + 1;
            note_name1[nn] = "D"; note_name2[nn] = "#"; nn = nn + 1;
            note_name1[nn] = "E"; note_name2[nn] = " "; nn = nn + 1;
            note_name1[nn] = "F"; note_name2[nn] = " "; nn = nn + 1;
            note_name1[nn] = "F"; note_name2[nn] = "#"; nn = nn + 1;
            note_name1[nn] = "G"; note_name2[nn] = " "; nn = nn + 1;
            note_name1[nn] = "G"; note_name2[nn] = "#"; nn = nn + 1;
            note_name1[nn] = "A"; note_name2[nn] = " "; nn = nn + 1;
            note_name1[nn] = "A"; note_name2[nn] = "#"; nn = nn + 1;
            note_name1[nn] = "B"; note_name2[nn] = " "; nn = nn + 1;
        end
    end

    // =====================================================
    // 3) 直接查找逻辑
    // =====================================================
    reg [15:0] freq_lat;
    reg [6:0] note_idx;
    reg [3:0] oct;
    
    // 查找音调索引的组合逻辑
    always @(*) begin
        note_idx = 0;
        
        // 首先检查边界情况
        if (detected_freq < freq_bound[0]) begin
            note_idx = 0; // 低于C0，返回C0
        end else if (detected_freq >= freq_bound[120]) begin
            note_idx = 119; // 高于B9，返回B9
        end else begin

            for (integer i = 0; i < 120; i = i + 1) begin
                if (detected_freq >= freq_bound[i] && detected_freq < freq_bound[i+1]) begin
                    note_idx = i;
                end
            end
        end
    end
    
    // 计算八度
    always @(*) begin
        oct = note_idx / 12;
    end
    
    // 当freq_valid=1时更新输出
    always @(posedge clk) begin
        if (!resetn) begin
            note_ascii1 <= " ";
            note_ascii2 <= " ";
            note_octave <= "0";
            freq_lat <= 0;
        end else if (freq_valid) begin
            // freq_valid=1时立即更新输出
            note_ascii1 <= note_name1[note_idx];
            note_ascii2 <= note_name2[note_idx];
            
            // 更新八度显示
            if (oct <= 4'd9)
                note_octave <= "0" + oct;
            else
                note_octave <= "9";
                
            // 同时缓存频率用于调试
            freq_lat <= detected_freq;
        end
    end

endmodule