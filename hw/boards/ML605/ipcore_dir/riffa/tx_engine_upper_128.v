`timescale 1ns/1ns
//----------------------------------------------------------------------------
// This software is Copyright © 2012 The Regents of the University of 
// California. All Rights Reserved.
//
// Permission to copy, modify, and distribute this software and its 
// documentation for educational, research and non-profit purposes, without 
// fee, and without a written agreement is hereby granted, provided that the 
// above copyright notice, this paragraph and the following three paragraphs 
// appear in all copies.
//
// Permission to make commercial use of this software may be obtained by 
// contacting:
// Technology Transfer Office
// 9500 Gilman Drive, Mail Code 0910
// University of California
// La Jolla, CA 92093-0910
// (858) 534-5815
// invent@ucsd.edu
// 
// This software program and documentation are copyrighted by The Regents of 
// the University of California. The software program and documentation are 
// supplied "as is", without any accompanying services from The Regents. The 
// Regents does not warrant that the operation of the program will be 
// uninterrupted or error-free. The end-user understands that the program was 
// developed for research purposes and is advised not to rely exclusively on 
// the program for any reason.
// 
// IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO
// ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR
// CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING
// OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
// EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF
// THE POSSIBILITY OF SUCH DAMAGE. THE UNIVERSITY OF
// CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
// THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, 
// AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATIONS TO
// PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
// MODIFICATIONS.
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
// Filename:			tx_engine_upper_128.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Formats read/write requests into PCI packets and adds 
// them to a FIFO. The FIFO will be read by the tx_engine_lower core and transmitted
// to the attached PCIe Endpoint.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
// Additional Comments: Very good PCIe header reference:
// http://www.pzk-agro.com/0321156307_ch04lev1sec5.html#ch04lev4sec14
// Also byte swap each payload word due to Xilinx incorrect mapping, see
// http://forums.xilinx.com/t5/PCI-Express/PCI-Express-payload-required-to-be-Big-Endian-by-specification/td-p/285551
//-----------------------------------------------------------------------------
`define FMT_TXENGUPR128_WR32	7'b10_00000
`define FMT_TXENGUPR128_RD32	7'b00_00000
`define FMT_TXENGUPR128_WR64	7'b11_00000
`define FMT_TXENGUPR128_RD64	7'b01_00000

`define S_TXENGUPR128_MAIN_IDLE		1'b0
`define S_TXENGUPR128_MAIN_WR		1'b1

`define S_TXENGUPR128_CAP_RD_WR		4'b0001
`define S_TXENGUPR128_CAP_WR_RD		4'b0010
`define S_TXENGUPR128_CAP_CAP		4'b0100
`define S_TXENGUPR128_CAP_REL		4'b1000

module tx_engine_upper_128 #(
	parameter C_PCI_DATA_WIDTH = 9'd128,
	parameter C_NUM_CHNL = 4'd12,
	parameter C_FIFO_DEPTH = 512,
	parameter C_TAG_WIDTH = 5, 							// Number of outstanding requests 
    parameter C_ALTERA = 1'b1,
	// Local parameters
	parameter C_FIFO_DEPTH_WIDTH = clog2((2**clog2(C_FIFO_DEPTH))+1),	
	parameter C_MAX_ENTRIES = (11'd128*11'd8/C_PCI_DATA_WIDTH),
	parameter C_DATA_DELAY = 3'd6 // Delays read/write params to accommodate tx_port_buffer delay and tx_engine_formatter delay.
)
(
	input CLK,
	input RST,

	input [15:0] CONFIG_COMPLETER_ID,
	input [2:0] CONFIG_MAX_PAYLOAD_SIZE,						// Maximum write payload: 000=128B, 001=256B, 010=512B, 011=1024B

	input [C_NUM_CHNL-1:0] WR_REQ,						// Write request
	input [(C_NUM_CHNL*64)-1:0] WR_ADDR,				// Write address
	input [(C_NUM_CHNL*10)-1:0] WR_LEN,					// Write data length
	input [(C_NUM_CHNL*C_PCI_DATA_WIDTH)-1:0] WR_DATA,	// Write data
	output [C_NUM_CHNL-1:0] WR_DATA_REN,				// Write data read enable
	output [C_NUM_CHNL-1:0] WR_ACK,						// Write request has been accepted

	input [C_NUM_CHNL-1:0] RD_REQ,						// Read request
	input [(C_NUM_CHNL*2)-1:0] RD_SG_CHNL,				// Read request channel for scatter gather lists
	input [(C_NUM_CHNL*64)-1:0] RD_ADDR,				// Read request address
	input [(C_NUM_CHNL*10)-1:0] RD_LEN,					// Read request length
	output [C_NUM_CHNL-1:0] RD_ACK,						// Read request has been accepted

	output [5:0] INT_TAG,								// Internal tag to exchange with external
	output INT_TAG_VALID,								// High to signal tag exchange 
	input [C_TAG_WIDTH-1:0] EXT_TAG,					// External tag to provide in exchange for internal tag
	input EXT_TAG_VALID,								// High to signal external tag is valid

    output 				      TX_ENG_RD_REQ_SENT, // Read completion request issued
    input 				      RXBUF_SPACE_AVAIL,

	output [C_PCI_DATA_WIDTH-1:0] FIFO_DATA,		 	// Formatted read/write request data
	input [C_FIFO_DEPTH_WIDTH-1:0] FIFO_COUNT, 			// Formatted read/write FIFO count
	output FIFO_WEN 									// Formatted read/write FIFO read enable	
);

`include "common_functions.v"

reg									rMainState=`S_TXENGUPR128_MAIN_IDLE, _rMainState=`S_TXENGUPR128_MAIN_IDLE;
reg									rCountIsWr=0, _rCountIsWr=0;
reg		[9:0]						rCountLen=0, _rCountLen=0;
reg		[3:0]						rCountChnl=0, _rCountChnl=0;
reg		[C_TAG_WIDTH-1:0]			rCountTag=0, _rCountTag=0;
reg		[61:0]						rCountAddr=62'd0, _rCountAddr=62'd0;
reg									rCountAddr64=0, _rCountAddr64=0;
reg		[9:0]						rCount=0, _rCount=0;
reg									rCountDone=0, _rCountDone=0;
reg									rCountValid=0, _rCountValid=0;
reg		[C_NUM_CHNL-1:0]			rWrDataRen=0, _rWrDataRen=0;

reg 								rTxEngRdReqAck, _rTxEngRdReqAck;
   
wire								wRdReq;
wire	[3:0]						wRdReqChnl;
wire								wWrReq;
wire	[3:0]						wWrReqChnl;
wire 								wRdAck;

wire	[3:0]						wCountChnl;
wire 	[11:0] 						wCountChnlShiftDW = (wCountChnl*C_PCI_DATA_WIDTH); // Mult can exceed 9 bits, so make this a wire
wire	[63:0]						wRdAddr = (RD_ADDR>>(wRdReqChnl*64));
wire	[9:0]						wRdLen = (RD_LEN>>(wRdReqChnl*10));
wire	[1:0]						wRdSgChnl = (RD_SG_CHNL>>(wRdReqChnl*2));
wire	[63:0]						wWrAddr = (WR_ADDR>>(wWrReqChnl*64));
wire	[9:0]						wWrLen = (WR_LEN>>(wWrReqChnl*10));
wire	[C_PCI_DATA_WIDTH-1:0]		wWrData = (WR_DATA>>wCountChnlShiftDW);
wire	[C_PCI_DATA_WIDTH-1:0]		wWrDataSwap;

reg		[3:0]						rRdChnl=0, _rRdChnl=0;
reg		[61:0]						rRdAddr=62'd0, _rRdAddr=62'd0;
reg		[9:0]						rRdLen=0, _rRdLen=0;
reg		[1:0]						rRdSgChnl=0, _rRdSgChnl=0;
reg		[3:0]						rWrChnl=0, _rWrChnl=0;
reg		[61:0]						rWrAddr=62'd0, _rWrAddr=62'd0;
reg		[9:0]						rWrLen=0, _rWrLen=0;
reg		[C_PCI_DATA_WIDTH-1:0]		rWrData={C_PCI_DATA_WIDTH{1'd0}}, _rWrData={C_PCI_DATA_WIDTH{1'd0}};

generate
if(C_ALTERA == 1'b1) begin : altera_data
	assign wWrDataSwap = rWrData;
end
else begin : xilinx_data
	assign wWrDataSwap = {rWrData[103:96], rWrData[111:104], rWrData[119:112], rWrData[127:120],
							rWrData[71:64], rWrData[79:72], rWrData[87:80], rWrData[95:88],
							rWrData[39:32], rWrData[47:40], rWrData[55:48], rWrData[63:56],
							rWrData[07:00], rWrData[15:08], rWrData[23:16], rWrData[31:24]};
end
endgenerate

(* syn_encoding = "user" *)
(* fsm_encoding = "user" *)
reg		[3:0]						rCapState=`S_TXENGUPR128_CAP_RD_WR, _rCapState=`S_TXENGUPR128_CAP_RD_WR;
reg		[C_NUM_CHNL-1:0]			rRdAck=0, _rRdAck=0;
reg		[C_NUM_CHNL-1:0]			rWrAck=0, _rWrAck=0;
reg									rIsWr=0, _rIsWr=0;
reg		[5:0]						rCapChnl=0, _rCapChnl=0;
reg		[61:0]						rCapAddr=62'd0, _rCapAddr=62'd0;
reg									rCapAddr64=0, _rCapAddr64=0;
reg		[9:0]						rCapLen=0, _rCapLen=0;
reg									rCapIsWr=0, _rCapIsWr=0;
reg									rExtTagReq=0, _rExtTagReq=0;
reg		[C_TAG_WIDTH-1:0]			rExtTag=0, _rExtTag=0;

reg		[C_FIFO_DEPTH_WIDTH-1:0]	rFifoCount=0, _rFifoCount=0;
reg		[9:0]						rMaxEntries=0, _rMaxEntries=0;
reg									rSpaceAvail=0, _rSpaceAvail=0;

reg		[C_DATA_DELAY-1:0]			rWnR=0, _rWnR=0;
reg		[(C_DATA_DELAY*4)-1:0]		rChnl=0, _rChnl=0;
reg		[(C_DATA_DELAY*8)-1:0]		rTag=0, _rTag=0;
reg		[(C_DATA_DELAY*62)-1:0]		rAddr=0, _rAddr=0;
reg		[C_DATA_DELAY-1:0]			rAddr64=0, _rAddr64=0;
reg		[(C_DATA_DELAY*10)-1:0]		rLen=0, _rLen=0;
reg		[C_DATA_DELAY-1:0]			rLenEQ1=0, _rLenEQ1=0;
reg		[C_DATA_DELAY-1:0]			rValid=0, _rValid=0;


assign WR_DATA_REN = rWrDataRen;
assign WR_ACK = rWrAck;
assign RD_ACK = rRdAck;

assign INT_TAG = {rRdSgChnl, rRdChnl};
assign INT_TAG_VALID = rExtTagReq;

assign TX_ENG_RD_REQ_SENT = rTxEngRdReqAck;
assign wRdAck = (wRdReq & EXT_TAG_VALID & RXBUF_SPACE_AVAIL);

// Search for the next request so that we can move onto it immediately after
// the current channel has released its request.
tx_engine_selector #(.C_NUM_CHNL(C_NUM_CHNL)) selRd (.RST(RST), .CLK(CLK), .REQ_ALL(RD_REQ), .REQ(wRdReq), .CHNL(wRdReqChnl));
tx_engine_selector #(.C_NUM_CHNL(C_NUM_CHNL)) selWr (.RST(RST), .CLK(CLK), .REQ_ALL(WR_REQ), .REQ(wWrReq), .CHNL(wWrReqChnl));


// Buffer shift-selected channel request signals and FIFO data.
always @ (posedge CLK) begin
	rRdChnl <= #1 _rRdChnl;
	rRdAddr <= #1 _rRdAddr;
	rRdLen <= #1 _rRdLen;
	rRdSgChnl <= #1 _rRdSgChnl;
	rWrChnl <= #1 _rWrChnl;
	rWrAddr <= #1 _rWrAddr;
	rWrLen <= #1 _rWrLen;
	rWrData <= #1 _rWrData;
end

always @ (*) begin
	_rRdChnl = wRdReqChnl;
	_rRdAddr = wRdAddr[63:2];
	_rRdLen = wRdLen;
	_rRdSgChnl = wRdSgChnl;
	_rWrChnl = wWrReqChnl;
	_rWrAddr = wWrAddr[63:2];
	_rWrLen = wWrLen;
	_rWrData = wWrData;
end

// Accept requests when the selector indicates. Capture the buffered 
// request parameters for hand-off to the formatting pipeline. Then
// acknowledge the receipt to the channel so it can deassert the 
// request, and let the selector choose another channel.
always @ (posedge CLK) begin
	rCapState <= #1 (RST ? `S_TXENGUPR128_CAP_RD_WR : _rCapState);
	rRdAck <= #1 (RST ? {C_NUM_CHNL{1'd0}} : _rRdAck);
	rWrAck <= #1 (RST ? {C_NUM_CHNL{1'd0}} : _rWrAck);
	rIsWr <= #1 _rIsWr;
	rCapChnl <= #1 _rCapChnl;
	rCapAddr <= #1 _rCapAddr;
	rCapAddr64 <= #1 _rCapAddr64;
	rCapLen <= #1 _rCapLen;
	rCapIsWr <= #1 _rCapIsWr;
	rExtTagReq <= #1 _rExtTagReq;
	rExtTag <= #1 _rExtTag;
      rTxEngRdReqAck <= #1 _rTxEngRdReqAck;
end

always @ (*) begin
	_rCapState = rCapState;
	_rRdAck = rRdAck;
	_rWrAck = rWrAck;
	_rIsWr = rIsWr;
	_rCapChnl = rCapChnl;
	_rCapAddr = rCapAddr;
	_rCapAddr64 = rCapAddr64;
	_rCapLen = rCapLen;
	_rCapIsWr = rCapIsWr;
	_rExtTagReq = rExtTagReq;
	_rExtTag = rExtTag;
    _rTxEngRdReqAck = rTxEngRdReqAck;

	case (rCapState) 

	`S_TXENGUPR128_CAP_RD_WR : begin
		_rIsWr = !wRdReq;
	   _rRdAck = ((wRdAck)<<wRdReqChnl);
	   _rTxEngRdReqAck = wRdAck;
	   _rExtTagReq = wRdAck;
	   _rCapState = (wRdAck ? `S_TXENGUPR128_CAP_CAP : `S_TXENGUPR128_CAP_WR_RD);
	end

	`S_TXENGUPR128_CAP_WR_RD : begin
		_rIsWr = wWrReq;
		_rWrAck = (wWrReq<<wWrReqChnl);
		_rCapState = (wWrReq ? `S_TXENGUPR128_CAP_CAP : `S_TXENGUPR128_CAP_RD_WR);
	end

	`S_TXENGUPR128_CAP_CAP : begin
	   	_rTxEngRdReqAck = 0;
		_rRdAck = 0;
		_rWrAck = 0;
		_rCapIsWr = rIsWr;
		_rExtTagReq = 0;
		_rExtTag = EXT_TAG;
		if (rIsWr) begin
			_rCapChnl = {2'd0, rWrChnl};
			_rCapAddr = rWrAddr;
			_rCapAddr64 = (rWrAddr[61:30] != 0);
			_rCapLen = rWrLen;
		end
		else begin
			_rCapChnl = {rRdSgChnl, rRdChnl};
			_rCapAddr = rRdAddr;
			_rCapAddr64 = (rRdAddr[61:30] != 0);
			_rCapLen = rRdLen;
		end
		_rCapState = `S_TXENGUPR128_CAP_REL;
	end
	
	`S_TXENGUPR128_CAP_REL : begin
		// Push into the formatting pipeline when ready
		if (rSpaceAvail & !rMainState) // S_TXENGUPR128_MAIN_IDLE
			_rCapState = (`S_TXENGUPR128_CAP_WR_RD>>(rCapIsWr)); // Changes to S_TXENGUPR128_CAP_RD_WR
	end
	
	default : begin
		_rCapState = `S_TXENGUPR128_CAP_RD_WR;
	end
	
	endcase
end


// Calculate the available space in the FIFO, accounting for the 
// formatting pipeline depth. This will be conservative.
wire [9:0] wMaxEntries = (C_MAX_ENTRIES<<CONFIG_MAX_PAYLOAD_SIZE) + 3'd5 + C_DATA_DELAY;
always @ (posedge CLK) begin
	rFifoCount <= #1 (RST ? {C_FIFO_DEPTH_WIDTH{1'd0}} : _rFifoCount);
	rMaxEntries <= #1 (RST ? 10'd0 : _rMaxEntries);
	rSpaceAvail <= #1 (RST ? 1'd0 : _rSpaceAvail);
end

always @ (*) begin
	_rFifoCount = FIFO_COUNT;
	_rMaxEntries = wMaxEntries;
	_rSpaceAvail = (rFifoCount + rMaxEntries < C_FIFO_DEPTH);
end


// Start the read/write when space is available in the output FIFO and when
// request parameters have been captured (i.e. a pending request).
always @ (posedge CLK) begin
	rMainState <= #1 (RST ? `S_TXENGUPR128_MAIN_IDLE : _rMainState);
	rCountIsWr <= #1 _rCountIsWr;
	rCountLen <= #1 _rCountLen;
	rCountChnl <= #1 _rCountChnl;
	rCountTag <= #1 _rCountTag;
	rCountAddr <= #1 _rCountAddr;
	rCountAddr64 <= #1 _rCountAddr64;
	rCount <= #1 _rCount;
	rCountDone <= #1 _rCountDone;
	rCountValid <= #1 _rCountValid;
	rWrDataRen <= #1 _rWrDataRen;
end

always @ (*) begin
	_rMainState = rMainState;
	_rCountIsWr = rCountIsWr;
	_rCountLen = rCountLen;
	_rCountChnl = rCountChnl;
	_rCountTag = rCountTag;
	_rCountAddr = rCountAddr;
	_rCountAddr64 = rCountAddr64;
	_rCount = rCount;
	_rCountDone = rCountDone;
	_rCountValid = rCountValid;
	_rWrDataRen = rWrDataRen;
	case (rMainState) 

	`S_TXENGUPR128_MAIN_IDLE : begin
		_rCountIsWr = rCapIsWr;
		_rCountLen = rCapLen;
		_rCountChnl = rCapChnl[3:0];
		_rCountTag = rExtTag;
		_rCountAddr = rCapAddr;
		_rCountAddr64 = rCapAddr64;
		_rCount = rCapLen;
		_rCountDone = (rCapLen <= 3'd4);
		_rWrDataRen = ((rSpaceAvail & rCapState[3] & rCapIsWr)<<(rCapChnl[3:0])); // S_TXENGUPR128_CAP_REL
		_rCountValid = (rSpaceAvail & rCapState[3]);
		if (rSpaceAvail && rCapState[3] && rCapIsWr && (rCapAddr64 || (rCapLen != 10'd1))) // S_TXENGUPR128_CAP_REL
			_rMainState = `S_TXENGUPR128_MAIN_WR;
	end

	`S_TXENGUPR128_MAIN_WR : begin
		_rCount = rCount - 3'd4;
		_rCountDone = (rCount <= 4'd8);
		if (rCountDone) begin
			_rWrDataRen = 0;
			_rCountValid = 0;
			_rMainState = `S_TXENGUPR128_MAIN_IDLE;
		end
	end
	
	endcase
end


// Shift in the captured parameters and valid signal every cycle.
// This pipeline will keep the formatter busy.
assign wCountChnl = rChnl[(C_DATA_DELAY-2)*4 +:4];
always @ (posedge CLK) begin
	rWnR <= #1 _rWnR;
	rChnl <= #1 _rChnl;
	rTag <= #1 _rTag;
	rAddr <= #1 _rAddr;
	rAddr64 <= #1 _rAddr64;
	rLen <= #1 _rLen;
	rLenEQ1 <= #1 _rLenEQ1;
	rValid <= #1 _rValid;
end

always @ (*) begin
	_rWnR = {rWnR[((C_DATA_DELAY-1)*1)-1:0], rCountIsWr};
	_rChnl = {rChnl[((C_DATA_DELAY-1)*4)-1:0], rCountChnl};
	_rTag = {rTag[((C_DATA_DELAY-1)*8)-1:0], (8'd0 | rCountTag)};
	_rAddr = {rAddr[((C_DATA_DELAY-1)*62)-1:0], rCountAddr};
	_rAddr64 = {rAddr64[((C_DATA_DELAY-1)*1)-1:0], rCountAddr64};
	_rLen = {rLen[((C_DATA_DELAY-1)*10)-1:0], rCountLen};
	_rLenEQ1 = {rLenEQ1[((C_DATA_DELAY-1)*1)-1:0], (rCountLen == 10'd1)};
	_rValid = {rValid[((C_DATA_DELAY-1)*1)-1:0], rCountValid};
end


// Format the read or write request into PCI packets. Note that
// the supplied WR_DATA must be synchronized to arrive the same
// cycle that VALID is asserted.
tx_engine_formatter_128 #(.C_PCI_DATA_WIDTH(C_PCI_DATA_WIDTH)) formatter (
	.RST(RST),
	.CLK(CLK),
	.CONFIG_COMPLETER_ID(CONFIG_COMPLETER_ID),
	.VALID(rValid[(C_DATA_DELAY-1)*1 +:1]),
	.WNR(rWnR[(C_DATA_DELAY-1)*1 +:1]),
	.CHNL(rChnl[(C_DATA_DELAY-1)*4 +:4]),
	.TAG(rTag[(C_DATA_DELAY-1)*8 +:8]),
	.ADDR(rAddr[(C_DATA_DELAY-1)*62 +:62]),
	.ADDR_64(rAddr64[(C_DATA_DELAY-1)*1 +:1]),
	.LEN(rLen[(C_DATA_DELAY-1)*10 +:10]),
	.LEN_ONE(rLenEQ1[(C_DATA_DELAY-1)*1 +:1]),
	.WR_DATA(wWrDataSwap),
	.OUT_DATA(FIFO_DATA),
	.OUT_DATA_WEN(FIFO_WEN)
);


endmodule
