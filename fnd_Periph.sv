`timescale 1ns / 1ps

/**
 * @brief FND(7-Segment) APB Peripheral
 */
module fnd_Periph (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // FND output signals
    output logic [ 7:0] fndFont, // 7-Segment Font (active-low)
    output logic [ 3:0] fndComm  // 4-Digit Common Anode (active-low)
);

    // APB Slave와 Controller 간의 내부 신호
    logic [15:0] fnd_data;   // 16비트 (4-bit BCD * 4 digits)
    logic        fnd_enable; // FND 스캔 활성화 비트

    // APB 슬레이브 인터페이스 인스턴스
    fnd_SlaveIntf U_fnd_Intf (
        .PCLK     (PCLK),
        .PRESET   (PRESET),
        .PADDR    (PADDR),
        .PWDATA   (PWDATA),
        .PWRITE   (PWRITE),
        .PENABLE  (PENABLE),
        .PSEL     (PSEL),
        .PRDATA   (PRDATA),
        .PREADY   (PREADY),
        .fnd_data (fnd_data),   // out
        .fnd_enable (fnd_enable)  // out
    );

    // FND 스캔 컨트롤러 인스턴스
    fndController U_fnd_Ctrl (
        .PCLK     (PCLK),
        .PRESET   (PRESET),
        .fnd_data (fnd_data),   // in
        .fnd_enable (fnd_enable), // in
        .fndFont  (fndFont),    // out
        .fndComm  (fndComm)     // out
    );

endmodule


module fnd_SlaveIntf (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // internal signals
    output logic [15:0] fnd_data,
    output logic        fnd_enable
);
    logic [31:0] slv_reg0; // FND_DATA_REG (16비트 사용)
    logic [31:0] slv_reg1; // FND_CTRL_REG (1비트 사용)

    assign fnd_data   = slv_reg0[15:0];
    assign fnd_enable = slv_reg1[0];

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 32'd0;
            slv_reg1 <= 32'd0;
            PREADY   <= 1'b0;
            PRDATA   <= 32'b0;
        end else begin
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE) begin // --- APB Write ---
                    case (PADDR[3:2])
                        2'd0: slv_reg0 <= PWDATA; // 0x00
                        2'd1: slv_reg1 <= PWDATA; // 0x04
                        default: ;
                    endcase
                    PRDATA <= 32'b0; 
                end else begin     // --- APB Read ---
                    case (PADDR[3:2])
                        2'd0: PRDATA <= slv_reg0; // 0x00
                        2'd1: PRDATA <= slv_reg1; // 0x04
                        default: PRDATA <= 32'bx;
                    endcase
                end
            end else begin
                PREADY <= 1'b0;
                PRDATA <= 32'b0; 
            end
        end
    end

endmodule


/**
 * @brief FND Scanning (Multiplexing) Controller
 */
module fndController (
    input  logic        PCLK,
    input  logic        PRESET,
    input  logic [15:0] fnd_data,   // 4-digit BCD data
    input  logic        fnd_enable, // Scan enable
    output logic [ 7:0] fndFont,    // 7-Segment Font (active-low)
    output logic [ 3:0] fndComm     // 4-Digit Common (active-low)
);

    // 100MHz 클럭 기준, 약 1ms 스캔 주기를 위한 카운터 (100_000 사이클)
    localparam int SCAN_DIV = 100_000; 
    logic [$clog2(SCAN_DIV)-1:0] scan_cnt;
    logic scan_tick;

    // 1ms마다 1-pulse tick 생성
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            scan_cnt  <= 0;
            scan_tick <= 1'b0;
        end else begin
            scan_tick <= 1'b0;
            if (scan_cnt == SCAN_DIV - 1) begin
                scan_cnt  <= 0;
                scan_tick <= 1'b1; 
            end else begin
                scan_cnt <= scan_cnt + 1;
            end
        end
    end

    // 현재 스캔할 자릿수 선택 (0, 1, 2, 3)
    logic [1:0] scan_sel; // 2-bit (0~3)
    
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            scan_sel <= 2'd0;
        end else if (scan_tick) begin // 1ms 마다
            scan_sel <= scan_sel + 1; // 0 -> 1 -> 2 -> 3 -> 0 ...
        end
    end

    // 현재 자릿수(scan_sel)에 맞는 BCD 데이터를 16비트 fnd_data에서 선택
    logic [3:0] bcd_data_mux;
    
    always_comb begin
        case(scan_sel)
            2'd0:    bcd_data_mux = fnd_data[ 3: 0]; // Digit 0 (우측 끝) (P)
            2'd1:    bcd_data_mux = fnd_data[ 7: 4]; // Digit 1 (o)
            2'd2:    bcd_data_mux = fnd_data[11: 8]; // Digit 2 (t)
            2'd3:    bcd_data_mux = fnd_data[15:12]; // Digit 3 (좌측 끝) (S)
            default: bcd_data_mux = 4'hF; 
        endcase
    end
    
    // BCD to 7-Segment Decoder 인스턴스
    BCDtoSEG U_BCD_to_SEG (
        .bcd(bcd_data_mux),
        .seg(fndFont) 
    ); 

    // 자릿수 선택(fndComm) 로직 (Common Anode, Active-Low)
    always_comb begin
        if (fnd_enable) begin // 스캔이 활성화되었을 때
            case(scan_sel)
                2'd0:    fndComm = 4'b1110; // Digit 0 (우측 끝)만 켬
                2'd1:    fndComm = 4'b1101; // Digit 1만 켬
                2'd2:    fndComm = 4'b1011; // Digit 2만 켬
                2'd3:    fndComm = 4'b0111; // Digit 3 (좌측 끝)만 켬
                default: fndComm = 4'b1111; // All off
            endcase
        end else begin
            fndComm = 4'b1111; // 스캔 비활성화 시 모든 FND 끔
        end
    end

endmodule


/**

 */
module BCDtoSEG (
    input  logic [3:0] bcd,
    output logic [7:0] seg
);

    always_comb begin
        case(bcd)
            4'h0: seg = 8'hc0; // 0
            4'h1: seg = 8'hf9; // 1
            4'h2: seg = 8'ha4; // 2
            4'h3: seg = 8'hb0; // 3
            4'h4: seg = 8'h99; // 4
            4'h5: seg = 8'h92; // 5
            4'h6: seg = 8'h82; // 6
            4'h7: seg = 8'hf8; // 7
            4'h8: seg = 8'h80; // 8
            4'h9: seg = 8'h90; // 9
            
            // --- ★★★ 수정된 폰트 맵 ★★★ ---
            4'ha: seg = 8'hc7; // 'L' (10)
            4'hb: seg = 8'haf; // 'r' (11)
            4'hc: seg = 8'h92; // 'S' (12) (5와 폰트 동일)
            4'hd: seg = 8'h87; // 't' (13) (기존 d 폰트 8'ha1)
            4'he: seg = 8'ha3; // 'o' (14) (기존 E 폰트 8'h86)
            4'hf: seg = 8'h8c; // 'P' (15) (기존 F 폰트 8'h8e)
            // --------------------------

            default: seg = 8'hff; // All off (blank)
        endcase
    end
endmodule