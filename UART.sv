`timescale 1ns / 1ps


module UART_Periph (
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // External Port
    input  logic        rx,
    output logic        tx
);


    logic [3:0] w_uart_cu;
    logic [7:0] w_UWDATA;
    logic [7:0] w_URDATA;
    logic       w_we_TX;
    logic       w_re_RX;


    APB_SlaveIntf_UART U_UART_Intf (
        .*,
        // Internal Port
        .uart_cu  (w_uart_cu),
        .UWDATA  (w_UWDATA),
        .URDATA  (w_URDATA),
        .we_TX(w_we_TX),
        .re_RX(w_re_RX)
    );


    UART U_UART (
        .clk(PCLK),
        .rst(PRESET),
        .rx(rx),
        .tx(tx),
        .uart_cu(w_uart_cu),
        .UWDATA(w_UWDATA),
        .URDATA(w_URDATA),
        .we_tx(w_we_TX),
        .re_rx(w_re_RX)
    );



endmodule


module APB_SlaveIntf_UART (
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // Internal Port
    input  logic [ 3:0] uart_cu,
    output logic [ 7:0] UWDATA,
    input  logic [ 7:0] URDATA,
    output logic        we_TX,
    output logic        re_RX
);

    logic [31:0] slv_reg0, slv_reg1, slv_reg2, slv_reg3;
    logic [31:0] slv_reg1_next, slv_reg2_next;

    logic we_reg, we_next;
    logic re_reg, re_next;
    logic [31:0] PRDATA_reg, PRDATA_next;
    logic PREADY_reg, PREADY_next;

    assign we_TX = we_reg;
    assign re_RX = re_reg;

    typedef enum {
        IDLE,
        READ,
        WRITE
    } state_e;

    state_e state_reg, state_next;

    assign slv_reg0[3:0] = uart_cu;
    assign UWDATA = slv_reg1[7:0];
    assign slv_reg2[7:0] = URDATA;

    assign PRDATA = PRDATA_reg;
    assign PREADY = PREADY_reg;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0[31:4] <= 0;  //uart_cu 
            slv_reg1       <= 0;  //uart_cu_RX
            slv_reg3[31:8] <= 0;
            slv_reg2       <= 0;
            state_reg      <= IDLE; 
            we_reg         <= 0;
            re_reg         <= 0;
            PRDATA_reg     <= 32'bx;
            PREADY_reg     <= 1'b0;
        end else begin
            slv_reg1   <= slv_reg1_next;
            slv_reg2   <= slv_reg2_next;
            state_reg  <= state_next;
            we_reg     <= we_next;
            re_reg     <= re_next;
            PRDATA_reg <= PRDATA_next;
            PREADY_reg <= PREADY_next;
        end
    end

    always_comb begin
        state_next    = state_reg;
        slv_reg1_next = slv_reg1;
        slv_reg2_next = slv_reg2;
        we_next       = we_reg;
        re_next       = re_reg;
        PRDATA_next   = PRDATA_reg;
        PREADY_next   = PREADY_reg;

        case (state_reg)
            IDLE: begin
                PREADY_next = 1'b0;
                if (PSEL && PENABLE) begin
                    if (PWRITE) begin
                        state_next = WRITE;
                        we_next = 1'b1;
                        re_next = 1'b0;
                        PREADY_next = 1'b1;
                        case (PADDR[3:2])
                            2'd0: ;
                            2'd1: slv_reg1_next = PWDATA;
                            2'd2: begin
                                slv_reg2_next = PWDATA;
                            end
                            2'd3: ;
                        endcase
                    end else begin
                        state_next = READ;
                        PREADY_next = 1'b1;
                        we_next = 1'b0;
                        case (PADDR[3:2])
                            2'd0: begin
                                PRDATA_next = slv_reg0;
                                re_next = 1'b0;
                            end
                            2'd1: begin
                                PRDATA_next = slv_reg1;
                                re_next = 1'b0;
                            end
                            2'd2: begin
                                PRDATA_next = slv_reg2;
                                re_next = 1'b0;
                            end
                            2'd3: begin
                                PRDATA_next = slv_reg3;
                                re_next = 1'b1;
                            end
                        endcase
                    end
                end
            end

            READ: begin
                re_next = 1'b0;
                we_next = 1'b0;
                PREADY_next = 1'b0;
                state_next = IDLE;
            end
            WRITE: begin
                we_next = 1'b0;
                re_next = 1'b0;
                state_next = IDLE;
                PREADY_next = 1'b0;
            end
        endcase
    end

endmodule



module UART (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic       tx,
    output logic [3:0] uart_cu,
    input  logic [7:0] UWDATA,
    output logic [7:0] URDATA,
    input  logic       we_tx,
    input logic       re_rx
);

    logic w_tick;
    logic w_rx_done;
    logic w_tx_busy;
    logic w_tx_fifo_empty;
    logic w_rx_fifo_empty;
    logic w_rx_fifo_full;
    logic w_tx_fifo_full;
    logic [7:0] w_rx_wdata, w_rx_rdata, w_tx_wdata, w_tx_rdata;

    assign uart_cu = {
        w_rx_fifo_full, w_tx_fifo_empty, w_tx_fifo_full, w_rx_fifo_empty
    };
    assign w_tx_wdata = UWDATA;
    assign URDATA = w_rx_rdata;


    baud_tick_gen U_BAUD_TICK_GEN (
        .rst (rst),
        .clk (clk),
        .tick(w_tick)
    );


    fifo U_UART_TX_FIFO (
        .clk(clk),
        .rst(rst),
        .wr(we_tx),
        .rd(~w_tx_busy),
        .wdata(w_tx_wdata),
        .rdata(w_tx_rdata),
        .full(w_tx_fifo_full),
        .empty(w_tx_fifo_empty)
    );
    fifo U_UART_RX_FIFO (
        .clk(clk),
        .rst(rst),
        .wr(w_rx_done),
        .rd(re_rx),
        .wdata(w_rx_wdata),
        .rdata(w_rx_rdata),
        .full(w_rx_fifo_full),
        .empty(w_rx_fifo_empty)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(~w_tx_fifo_empty),
        .tx_data(w_tx_rdata),
        .tick(w_tick),
        .tx_busy(w_tx_busy),
        .tx(tx)
    );


    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .tick(w_tick),
        .rx(rx),
        .rx_data(w_rx_wdata),
        .rx_done(w_rx_done)
    );


endmodule



module uart_rx (
    input  logic       clk,
    input  logic       rst,
    input  logic       tick,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_done
);

    parameter [1:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;
    logic [1:0] c_state, n_state;

    logic [4:0] tick_cnt_reg, tick_cnt_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;

    logic rx_done_reg, rx_done_next;
    logic [7:0] rx_buf_reg, rx_buf_next;

    assign rx_data = rx_buf_reg;
    assign rx_done = rx_done_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            tick_cnt_reg <= 0;
            bit_cnt_reg <= 0;
            rx_done_reg <= 0;
            rx_buf_reg <= 0;
        end else begin
            c_state <= n_state;
            tick_cnt_reg <= tick_cnt_next;
            bit_cnt_reg <= bit_cnt_next;
            rx_done_reg <= rx_done_next;
            rx_buf_reg <= rx_buf_next;
        end
    end


    always @(*) begin
        n_state = c_state;
        tick_cnt_next = tick_cnt_reg;
        bit_cnt_next = bit_cnt_reg;
        rx_done_next = rx_done_reg;
        //rx_done_next = 0;
        rx_buf_next = rx_buf_reg;

        case (c_state)
            IDLE: begin
                rx_done_next = 1'b0;
                if (!rx) begin
                    tick_cnt_next = 0;
                    n_state = START;
                end
            end

            START: begin
                if (tick) begin
                    if (tick_cnt_reg == 23) begin
                        tick_cnt_next = 0;
                        bit_cnt_next = 0;
                        n_state = DATA;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                if (tick) begin
                    if (tick_cnt_reg == 7) begin
                        rx_buf_next = {rx, rx_buf_reg[7:1]};
                    end

                    if (tick_cnt_reg == 15) begin
                        tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                if (tick) begin
                    if (tick_cnt_reg == 15) begin
                        rx_done_next = 1'b1;
                        n_state = IDLE;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            default: begin
                n_state = IDLE;
                tick_cnt_next = 0;
                bit_cnt_next = 0;
                rx_done_next = 0;
                rx_buf_next = 0;
            end
        endcase
    end


endmodule



module uart_tx (
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    input  logic       tick,
    output logic       tx_busy,
    output logic       tx
);

    localparam [1:0] IDLE = 2'b00, TX_START = 2'b01, TX_DATA = 2'b10, TX_STOP = 2'b11;

    logic [1:0] c_state, n_state;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic [3:0] tick_cnt_reg, tick_cnt_next;
    logic [7:0] data_buf_reg, data_buf_next;
    logic tx_reg, tx_next;
    logic tx_busy_reg, tx_busy_next;

    assign tx_busy = tx_busy_reg;
    assign tx = tx_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state      <= IDLE;
            bit_cnt_reg  <= 3'b000;
            tick_cnt_reg <= 4'b0000;
            data_buf_reg <= 8'h00;
            tx_reg       <= 1'b1;
            tx_busy_reg  <= 1'b0;
        end else begin
            c_state      <= n_state;
            bit_cnt_reg  <= bit_cnt_next;
            tick_cnt_reg <= tick_cnt_next;
            data_buf_reg <= data_buf_next;
            tx_reg       <= tx_next;
            tx_busy_reg  <= tx_busy_next;
        end
    end

    always @(*) begin
        n_state       = c_state;
        bit_cnt_next  = bit_cnt_reg;
        tick_cnt_next = tick_cnt_reg;
        data_buf_next = data_buf_reg;
        tx_next       = tx_reg;
        tx_busy_next  = tx_busy_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                tx_busy_next = 1'b0;
                if (tx_start) begin
                    tick_cnt_next = 0;
                    data_buf_next = tx_data;
                    n_state = TX_START;
                end
            end
            TX_START: begin
                tx_next = 1'b0;
                tx_busy_next = 1'b1;
                if (tick) begin
                    if (tick_cnt_reg == 15) begin
                        tick_cnt_next = 0;
                        bit_cnt_next = 0;
                        n_state = TX_DATA;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            TX_DATA: begin
                tx_next = data_buf_reg[0];
                if (tick) begin
                    if (tick_cnt_reg == 15) begin
                        //tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            tick_cnt_next = 0;
                            n_state = TX_STOP;
                        end else begin
                            tick_cnt_next = 0;
                            bit_cnt_next  = bit_cnt_reg + 1;
                            data_buf_next = data_buf_reg >> 1;
                        end
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            TX_STOP: begin
                tx_next = 1'b1;
                if (tick) begin
                    if (tick_cnt_reg == 15) begin
                        tx_busy_next = 1'b0;
                        n_state = IDLE;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end




endmodule



module fifo (
    input  logic       clk,
    input  logic       rst,
    input  logic       wr,
    input  logic       rd,
    input  logic [7:0] wdata,
    output logic [7:0] rdata,
    output logic       full,
    output logic       empty
);

    logic [2:0] waddr;
    logic [2:0] raddr;
    logic w_en;

    assign wr_en = wr & ~full;

    register_file U_REG_FILE (
        .*,
        .wr(wr_en)
    );
    fifo_control_unit U_FIFO_CU (.*);

endmodule



module register_file #(
    parameter AWIDTH = 3
) (
    input  logic              clk,
    input  logic              wr,
    input  logic [       7:0] wdata,
    input  logic [AWIDTH-1:0] waddr,
    input  logic [AWIDTH-1:0] raddr,
    output logic [       7:0] rdata
);

    logic [7:0] ram[0:2**AWIDTH-1];
    assign rdata = ram[raddr];

    always_ff @(posedge clk) begin
        if (wr) begin
            ram[waddr] <= wdata;
        end
    end

endmodule




module fifo_control_unit #(
    parameter AWIDTH = 3
) (
    input  logic              clk,
    input  logic              rst,
    input  logic              wr,
    input  logic              rd,
    output logic [AWIDTH-1:0] waddr,
    output logic [AWIDTH-1:0] raddr,
    output logic              full,
    output logic              empty
);

    logic [AWIDTH-1:0] waddr_reg, waddr_next;
    logic [AWIDTH-1:0] raddr_reg, raddr_next;

    logic full_reg, full_next;
    logic empty_reg, empty_next;

    assign full  = full_reg;
    assign empty = empty_reg;

    assign waddr = waddr_reg;
    assign raddr = raddr_reg;

    // state reg
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            waddr_reg <= 0;
            raddr_reg <= 0;
            full_reg  <= 0;
            empty_reg <= 1'b1;
        end else begin
            waddr_reg <= waddr_next;
            raddr_reg <= raddr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    // next CL
    always_comb begin
        waddr_next = waddr_reg;
        raddr_next = raddr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;
        case ({
            wr, rd
        })
            2'b01: begin  //pop
                if (!empty_reg) begin
                    raddr_next = raddr_reg + 1;
                    full_next  = 1'b0;
                    if (waddr_reg == raddr_next) begin
                        empty_next = 1'b1;
                    end
                end
            end
            2'b10: begin  // push
                if (!full_reg) begin
                    waddr_next = waddr_reg + 1;
                    empty_next = 1'b0;
                    if (waddr_next == raddr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end
            2'b11: begin  // push pop
                if (full_reg) begin
                    // pop
                    raddr_next = raddr_reg + 1;
                    full_next  = 1'b0;
                end else if (empty_reg) begin
                    //push
                    waddr_next = waddr_reg + 1;
                    empty_next = 1'b0;
                end else begin
                    raddr_next = raddr_reg + 1;
                    waddr_next = waddr_reg + 1;
                end
            end
        endcase
    end
endmodule



module baud_tick_gen (
    input  rst,
    input  clk,
    output tick
);

    parameter BAUDRATE = 9600 * 16;
    localparam BAUD_COUNT = 100_000_000 / BAUDRATE;

    reg [$clog2(BAUD_COUNT)-1:0] counter_reg, counter_next;
    reg tick_reg, tick_next;

    assign tick = tick_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 1'b0;
            tick_reg <= 1'b0;
        end else begin
            counter_reg <= counter_next;
            tick_reg <= tick_next;
        end
    end

    always @(*) begin
        counter_next = counter_reg;
        tick_next = tick_reg;
        if (counter_reg == BAUD_COUNT - 1) begin
            counter_next = 1'b0;
            tick_next = 1'b1;
        end else begin
            counter_next = counter_reg + 1;
            tick_next = 1'b0;
        end
    end


endmodule
