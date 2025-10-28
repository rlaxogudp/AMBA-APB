`timescale 1ns / 1ps

module GPIO_Periph (
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
    inout  logic [ 7:0] gpio
);
 
    // Internal Ports
    logic [7:0] cr;
    logic [7:0] odr;
    logic [7:0] idr;

    APB_SlaveInfr_GPIO U_APB_SlaveInterf_GPIO (.*);
    GPIO U_GPIO (.*);

endmodule

module APB_SlaveInfr_GPIO (
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
    // Internal Ports
    output logic [ 7:0] cr,
    output logic [ 7:0] odr,
    input  logic [ 7:0] idr
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2;

    assign cr  = slv_reg0[7:0];
    assign odr = slv_reg1[7:0];

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            slv_reg2 <= 0;
        end else begin
            PREADY <= 1'b0;
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE) begin
                    case (PADDR[3:2])
                        2'd0: slv_reg0 <= PWDATA;
                        2'd1: slv_reg1 <= PWDATA;
                        2'd2: ;  //slv_reg2 <= PWDATA; Input을 write x
                        2'd3: ;
                    endcase
                end else begin
                    case (PADDR[3:2])
                        2'd0: PRDATA <= slv_reg0;
                        2'd1: PRDATA <= slv_reg1;
                        2'd2: PRDATA <= {24'b0, idr};
                        2'd3: ;
                    endcase
                end
            end
        end
    end
endmodule

module GPIO (
    input  logic [7:0] cr,
    input  logic [7:0] odr,
    output logic [7:0] idr,
    inout  logic [7:0] gpio
);

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin
            assign gpio[i] = cr[i] ? odr[i] : 1'bz;
            assign idr[i]  = ~cr[i] ? gpio[i] : 1'bz;
        end
    endgenerate

    // assign gpio[0] = cr ? odr[0] : 1'bz;
    // assign idr[0] = ~cr[0] ? gpio[0] : 1'bz;

endmodule
