/*
	Copyright 2020 Mohamed Shalan

	Licensed under the Apache License, Version 2.0 (the "License"); 
	you may not use this file except in compliance with the License. 
	You may obtain a copy of the License at:

	http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software 
	distributed under the License is distributed on an "AS IS" BASIS, 
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
	See the License for the specific language governing permissions and 
	limitations under the License.
*/

`timescale          1ns/1ps
`default_nettype    none

/*
    Registers                   Offset      Size        Fields
    Source Addrerss             0x00        32          n/a
    Destination Address         0x04        32          n/a
    Control Register            0x08        1           0:   start
    Source Configuration        0x0C        8           2-0: Source Size (0, 1, or 2)
                                                        6-4: Source Increment (0, 1, 2, or 4) 
    Destination Configuration   0x10        8           2-0: Source Size (0, 1, or 2)
                                                        6-4: Source Increment (0, 1, 2, or 4) 
    IRQ Configuration           0x14        8           0:   Wait for IRQ Enable
                                                        6-4: IRQ Source (0-7)
    Block Count (num of blocks) 0x18        8           n/a
    Block Size                  0x1C        16          n/a
    Status                      0x20        2           0: done
                                                        1: busy
*/

`define     AHBL_REG(r) \
    wire    ``r``_sel = (last_HADDR[15:0] == ``r``_off); \
    always @(posedge HCLK, negedge HRESETn) \
        if(!HRESETn)\
            r <= 'h0;\
        else if(wr_enable & ``r``_sel)\
            r <= sHWDATA;\

`define     AHBL_REG_SC(r) \
    wire    ``r``_sel = (last_HADDR[15:0] == ``r``_off); \
    always @(posedge HCLK, negedge HRESETn) \
        if(!HRESETn)\
            r <= 'h0;\
        else if(wr_enable & ``r``_sel)\
            r <= sHWDATA;\
        else\
            r <= 1'b0;


`define     AHBL_READ(r)\
    ``r``_sel ? r :

module ahbl_dmac (
    input   wire        HCLK,
    input   wire        HRESETn,

    output  wire [31:0] mHADDR,
    output  wire [1:0]  mHTRANS,
    output  wire [2:0] 	mHSIZE,
    output  wire        mHWRITE,
    output  wire [31:0] mHWDATA,
    input   wire        mHREADY,
    input   wire [31:0] mHRDATA,

    input   wire [7:0]  PIRQ,

    input   wire [31:0] sHADDR,
    input   wire [1:0]  sHTRANS,
    input   wire [2:0] 	sHSIZE,
    input   wire        sHWRITE,
    input   wire [31:0] sHWDATA,
    input   wire        sHREADY,
    input   wire        sHSEL,
    output  wire        sHREADYOUT,
    output  wire [31:0] sHRDATA,

    output              IRQ

);
    localparam  SADDR_off   = 0, 
                DADDR_off   = 4,
                CTRL_off    = 8,
                SCFG_off    = 12,
                DCFG_off    = 16,
                CFG_off     = 20,
                BCOUNT_off  = 24,
                BSIZE_off   = 28,
                STATUS_off  = 32;

    wire [31:0] saddr;
    wire [31:0] daddr;
    wire [2:0]  ssize;
    wire [2:0]  dsize;
    wire [2:0]  sinc;
    wire [2:0]  dinc;
    wire [7:0]  bsize;
    wire [7:0]  bcount;
    wire        start;
    wire        wfi;
    wire [2:0]  irqsrc;
    //wire [7:0]  pirq;

    wire        done;
    wire        busy;

    dmac_master master (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HADDR(mHADDR),
        .HTRANS(mHTRANS),
        .HSIZE(mHSIZE),
        .HWRITE(mHWRITE),
        .HWDATA(mHWDATA),
        .HREADY(mHREADY),
        .HRDATA(mHRDATA),

        .saddr(saddr),
        .daddr(daddr),
        .ssize(ssize),
        .dsize(dsize),
        .sinc(sinc),
        .dinc(dinc),
        .bsize(bsize),
        .bcount(bcount),
        .start(start),
        .wfi(wfi),
        .irqsrc(irqsrc),
        .pirq(PIRQ),

        .done(done),
        .busy(busy)
    );

    reg             last_HSEL; 
    reg [31:0]      last_HADDR; 
    reg             last_HWRITE; 
    reg [1:0]       last_HTRANS;
    
    always@ (posedge HCLK or negedge HRESETn) begin
		if (!HRESETn) begin
			last_HSEL       <= 0;
			last_HADDR      <= 0;
			last_HWRITE     <= 0;
			last_HTRANS     <= 0;
		end else if(sHREADY) begin
			last_HSEL       <= sHSEL;
			last_HADDR      <= sHADDR;
			last_HWRITE     <= sHWRITE;
			last_HTRANS     <= sHTRANS;
		end
	end
    
    wire rd_enable = last_HSEL & (~last_HWRITE) & last_HTRANS[1]; 
    wire wr_enable = last_HSEL & (last_HWRITE) & last_HTRANS[1];

    reg [31:0]  SADDR, DADDR;
    reg [0:0]   CTRL;
    reg [7:0]   SCFG;
    reg [7:0]   DCFG;
    reg [7:0]   CFG;
    reg [7:0]   BCOUNT;
    reg [7:0]   BSIZE;
    reg [1:0]   STATUS;

    assign saddr    = SADDR;
    assign daddr    = DADDR;
    assign start    = CTRL[0];
    assign ssize    = SCFG[2:0];
    assign sinc     = SCFG[6:4];
    assign dsize    = DCFG[2:0];
    assign dinc     = DCFG[6:4];
    assign wfi      = CFG[0];
    assign irqsrc   = CFG[6:4];
    assign bcount   = BCOUNT;
    assign bsize    = BSIZE;

    `AHBL_REG(SADDR);
    `AHBL_REG(DADDR);
    `AHBL_REG_SC(CTRL);
    `AHBL_REG(DCFG);
    `AHBL_REG(SCFG);
    `AHBL_REG(CFG);
    `AHBL_REG(BCOUNT);
    `AHBL_REG(BSIZE);

    wire  STATUS_sel = (last_HADDR[15:0] == STATUS_off);
    always@(posedge HCLK, negedge HRESETn)
        if(!HRESETn)
            STATUS <= 2'b0;
        else begin
            STATUS[1] <= busy;
            if(done)
                STATUS <= 1'b1;
            else if(STATUS_sel & rd_enable)
                STATUS[0] <= 1'b0;
            end

    assign sHREADYOUT = 1'b1;

    assign sHRDATA =    `AHBL_READ(SADDR)
                        `AHBL_READ(DADDR)
                        `AHBL_READ(CTRL)
                        `AHBL_READ(CFG)
                        `AHBL_READ(DCFG)
                        `AHBL_READ(SCFG)
                        `AHBL_READ(BCOUNT)
                        `AHBL_READ(BSIZE)
                        `AHBL_READ(STATUS)
                        32'hBAD0F00D;

    assign IRQ = STATUS;

endmodule
    