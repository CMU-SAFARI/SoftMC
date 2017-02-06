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
// Filename:			rx_engine_64.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Receive engine for PCIe using AXI interface from Xilinx 
//						PCIe Endpoint core.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
// Additional Comments: Very good PCIe header reference:
// http://www.pzk-agro.com/0321156307_ch04lev1sec5.html#ch04lev4sec14
// Also byte swap each payload word due to Xilinx incorrect mapping, see
// http://forums.xilinx.com/t5/PCI-Express/PCI-Express-payload-required-to-be-Big-Endian-by-specification/td-p/285551
//-----------------------------------------------------------------------------
`define FMT_RXENG64_RD32	7'b00_00000
`define FMT_RXENG64_WR32	7'b10_00000
`define FMT_RXENG64_RD64	7'b01_00000
`define FMT_RXENG64_WR64	7'b11_00000
`define FMT_RXENG64_CPL		7'b00_01010
`define FMT_RXENG64_CPLD	7'b10_01010

`define S_RXENG64_REQ_PARSE			3'd0
`define S_RXENG64_REQ_UNHANDLED		3'd1
`define S_RXENG64_REQ_MEM_RD_0		3'd2
`define S_RXENG64_REQ_MEM_WR_0		3'd3
`define S_RXENG64_REQ_MEM_WR_1		3'd4

`define S_RXENG64_CPL_PARSE			3'd0
`define S_RXENG64_CPL_WAIT_FOR_END	3'd1
`define S_RXENG64_CPL_NO_DATA		3'd2
`define S_RXENG64_CPL_DATA			3'd3
`define S_RXENG64_CPL_DATA_CONT		3'd4

module rx_engine_64 #(
	parameter C_PCI_DATA_WIDTH = 9'd64,
	parameter C_NUM_CHNL = 4'd12,
	parameter C_MAX_READ_REQ_BYTES = 512,			// Max size of read requests (in bytes)
	parameter C_TAG_WIDTH = 5, 						// Number of outstanding requests 
	parameter C_ALTERA = 1'b1,						// 1 if Altera, 0 if Xilinx
	// Local parameters
	parameter C_PCI_DATA_WORD = C_PCI_DATA_WIDTH/32,
	parameter C_PCI_DATA_COUNT_WIDTH = clog2s(C_PCI_DATA_WORD+1)
)
(
	input CLK,
	input RST,
	// Receive
	input [C_PCI_DATA_WIDTH-1:0] RX_DATA,
	input [(C_PCI_DATA_WIDTH/8)-1:0] RX_DATA_BYTE_ENABLE,
	input RX_TLP_END_FLAG,
	input RX_DATA_VALID,
	output RX_DATA_READY,
	input RX_TLP_ERROR_POISON,
	// Received read/write memory requests
	output REQ_WR,													// Memory write request
	input REQ_WR_DONE,												// Memory write completed
	output REQ_RD,													// Memory read request
	input REQ_RD_DONE,												// Memory read complete
	output [9:0] REQ_LEN,											// Memory length (1DW)
	output [29:0] REQ_ADDR,											// Memory address (bottom 2 bits are always 00)
	output [31:0] REQ_DATA,											// Memory write data
	output [3:0] REQ_BE,											// Memory byte enables
	output [2:0] REQ_TC,											// Memory traffic class
	output REQ_TD,                  								// Memory packet digest
	output REQ_EP,      											// Memory poisoned packet
	output [1:0] REQ_ATTR,											// Memory packet relaxed ordering, no snoop
	output [15:0] REQ_ID,											// Memory requestor id
	output [7:0] REQ_TAG,											// Memory packet tag
	// Tag exchange
	input [5:0] INT_TAG,											// Internal tag to exchange with external
	input INT_TAG_VALID,											// High to signal tag exchange 
	output [C_TAG_WIDTH-1:0] EXT_TAG,								// External tag to provide in exchange for internal tag
	output EXT_TAG_VALID,											// High to signal external tag is valid
	// Received read completions
    output ENG_RD_COMPLETE, 
	output [C_PCI_DATA_WIDTH-1:0] ENG_DATA,							// Engine data 
	output [(C_NUM_CHNL*C_PCI_DATA_COUNT_WIDTH)-1:0] MAIN_DATA_EN,	// Main data enable
	output [C_NUM_CHNL-1:0] MAIN_DONE,								// Main data complete
	output [C_NUM_CHNL-1:0] MAIN_ERR,								// Main data completed with error
	output [(C_NUM_CHNL*C_PCI_DATA_COUNT_WIDTH)-1:0] SG_RX_DATA_EN,	// Scatter gather for RX data enable
	output [C_NUM_CHNL-1:0] SG_RX_DONE,								// Scatter gather for RX data complete
	output [C_NUM_CHNL-1:0] SG_RX_ERR,								// Scatter gather for RX data completed with error
	output [(C_NUM_CHNL*C_PCI_DATA_COUNT_WIDTH)-1:0] SG_TX_DATA_EN,	// Scatter gather for TX data enable
	output [C_NUM_CHNL-1:0] SG_TX_DONE,								// Scatter gather for TX data complete
	output [C_NUM_CHNL-1:0] SG_TX_ERR								// Scatter gather for TX data completed with error
);

`include "common_functions.v"


reg		[2:0]						rTrigger=0, _rTrigger=0;
reg		[C_PCI_DATA_WIDTH-1:0]		rDataIn=0, _rDataIn=0;
reg									rValidIn=0, _rValidIn=0;
reg									rKeepBothIn=0, _rKeepBothIn=0;
reg									rLastIn=0, _rLastIn=0;
reg									rLenOneIn=0, _rLenOneIn=0;

reg		[2:0]						rReqState=`S_RXENG64_REQ_PARSE, _rReqState=`S_RXENG64_REQ_PARSE;
reg		[29:0]						rReqAddr=0, _rReqAddr=0;
reg		[31:0]						rReqData=0, _rReqData=0;
reg									rReqWen=0, _rReqWen=0;
reg									rRNW=0, _rRNW=0;
reg		[3:0]						rBE=0, _rBE=0;
reg		[2:0]						rTC=0, _rTC=0;
reg									rTD=0, _rTD=0;
reg									rEP=0, _rEP=0;
reg		[1:0]						rAttr=0, _rAttr=0;
reg		[9:0]						rReqLen=0, _rReqLen=0;
reg		[15:0]						rReqId=0, _rReqId=0;
reg		[7:0]						rReqTag=0, _rReqTag=0;
reg									r3DWHeader=0, _r3DWHeader=0;

reg		[2:0]						rCplState=`S_RXENG64_CPL_PARSE, _rCplState=`S_RXENG64_CPL_PARSE;
reg									rCplErr=0, _rCplErr=0;
reg									rLastCPLD=0, _rLastCPLD=0;

reg		[C_PCI_DATA_COUNT_WIDTH-1:0]rDataOutCount=0, _rDataOutCount=0;
reg		[C_PCI_DATA_WORD-1:0]		rDataOutEn=0, _rDataOutEn=0;
reg		[C_PCI_DATA_WIDTH-1:0]		rDataOut={C_PCI_DATA_WIDTH{1'b0}}, _rDataOut={C_PCI_DATA_WIDTH{1'b0}};
reg									rDataDone=0, _rDataDone=0;
reg									rDataErr=0, _rDataErr=0;
reg									rDataValid=0, _rDataValid=0;
reg		[7:0]						rChnlShft=0, _rChnlShft=0;

reg                                 rQWACpl,_rQWACpl;
reg                                 rQWAReq,_rQWAReq;

wire                                wALTERA = C_ALTERA;

wire [31:0]                         wReqData;
wire [C_PCI_DATA_WIDTH-1:0]         wDataOut;

assign wReqData = wALTERA? rReqData :{rReqData[7:0], rReqData[15:8], rReqData[23:16], rReqData[31:24]};
assign wDataOut = wALTERA? rDataOut :{rDataOut[39:32], rDataOut[47:40], rDataOut[55:48], rDataOut[63:56],
									rDataOut[07:00], rDataOut[15:08], rDataOut[23:16], rDataOut[31:24]};
assign RX_DATA_READY = 1;
assign ENG_RD_COMPLETE = rDataDone;

// Handle servicing write & read memory requests in a separate state machine.
rx_engine_req #( 
	.C_NUM_CHNL(C_NUM_CHNL)
) rxEngReq (
	.CLK(CLK), 
	.RST(RST), 
	.REQ_WR(REQ_WR), 
	.REQ_WR_DONE(REQ_WR_DONE), 
	.REQ_RD(REQ_RD), 
	.REQ_RD_DONE(REQ_RD_DONE), 
	.REQ_LEN(REQ_LEN), 
	.REQ_ADDR(REQ_ADDR), 
	.REQ_DATA(REQ_DATA), 
	.REQ_BE(REQ_BE), 
	.REQ_TC(REQ_TC), 
	.REQ_TD(REQ_TD), 
	.REQ_EP(REQ_EP), 
	.REQ_ATTR(REQ_ATTR), 
	.REQ_ID(REQ_ID), 
	.REQ_TAG(REQ_TAG),
	.WEN(rReqWen),
	.RNW(rRNW),
	.LEN(rReqLen), 
	.ADDR(rReqAddr), 
	.DATA(wReqData), 
	.BE(rBE), 
	.TC(rTC), 
	.TD(rTD), 
	.EP(rEP), 
	.ATTR(rAttr), 
	.ID(rReqId), 
	.TAG(rReqTag)
);


// Handle reordering completion data.
reorder_queue #( 
	.C_PCI_DATA_WIDTH(C_PCI_DATA_WIDTH),
	.C_NUM_CHNL(C_NUM_CHNL),
	.C_MAX_READ_REQ_BYTES(C_MAX_READ_REQ_BYTES),
	.C_TAG_WIDTH(C_TAG_WIDTH)
) reorderQueue (
	.CLK(CLK), 
	.RST(RST), 
	.VALID(rDataValid), 
	.DATA(wDataOut), 
	.DATA_EN(rDataOutEn), 
	.DATA_EN_COUNT(rDataOutCount), 
	.DONE(rDataDone), 
	.ERR(rDataErr), 
	.TAG(rChnlShft[C_TAG_WIDTH-1:0]), 
	.INT_TAG(INT_TAG), 
	.INT_TAG_VALID(INT_TAG_VALID), 
	.EXT_TAG(EXT_TAG), 
	.EXT_TAG_VALID(EXT_TAG_VALID), 
	.ENG_DATA(ENG_DATA), 
	.MAIN_DATA_EN(MAIN_DATA_EN), 
	.MAIN_DONE(MAIN_DONE),
	.MAIN_ERR(MAIN_ERR),
	.SG_RX_DATA_EN(SG_RX_DATA_EN),
	.SG_RX_DONE(SG_RX_DONE),
	.SG_RX_ERR(SG_RX_ERR), 
	.SG_TX_DATA_EN(SG_TX_DATA_EN), 
	.SG_TX_DONE(SG_TX_DONE), 
	.SG_TX_ERR(SG_TX_ERR)
);


// Handle receiving data from PCIe receive channel.
wire wValid = (RX_DATA_VALID & !RX_TLP_ERROR_POISON);
always @ (posedge CLK) begin
	rTrigger <= #1 (RST ? 3'd0 : _rTrigger);
	rValidIn <= #1 (RST ? 1'd0 : _rValidIn);
	rDataIn <= #1 _rDataIn;
	rKeepBothIn <= #1 _rKeepBothIn;
	rLastIn <= #1 _rLastIn;
	rLenOneIn <= #1 _rLenOneIn;
    rQWACpl <= #1 _rQWACpl;
end

always @ (*) begin
	_rDataIn = rDataIn;
	_rValidIn = rValidIn;
	_rKeepBothIn = rKeepBothIn;
	_rLastIn = rLastIn;
	_rLenOneIn = rLenOneIn;
	_rTrigger = rTrigger;
    _rQWACpl = rQWACpl;

	// Buffer the incoming data
	_rDataIn = RX_DATA;
	_rValidIn = (RX_DATA_VALID && !RX_TLP_ERROR_POISON);
	_rKeepBothIn = (RX_DATA_BYTE_ENABLE == 8'hFF);
	_rLastIn = RX_TLP_END_FLAG;
	_rLenOneIn = (RX_DATA[9:0] == 10'd1);
    _rQWACpl = ~RX_DATA[2];

	// Direct the main FSM with what kind of packet this represents
	case (RX_DATA[30:24])
		`FMT_RXENG64_RD32 :	_rTrigger = 3'd1 & ({3{wValid}});
		`FMT_RXENG64_RD64 :	_rTrigger = 3'd1 & ({3{wValid}});
		`FMT_RXENG64_WR32 :	_rTrigger = 3'd2 & ({3{wValid}});
		`FMT_RXENG64_WR64 :	_rTrigger = 3'd2 & ({3{wValid}});
		`FMT_RXENG64_CPL  :	_rTrigger = 3'd3 & ({3{wValid}});
		`FMT_RXENG64_CPLD :	_rTrigger = 3'd4 & ({3{wValid}});
		default			  :	_rTrigger = 3'd5 & ({3{wValid}});
	endcase
end


// Handle receiving memory reads and writes.
always @ (posedge CLK) begin
	rReqState <= #1 (RST ? `S_RXENG64_REQ_PARSE : _rReqState);
	rReqWen <= #1 (RST ? 1'd0 : _rReqWen);
	rRNW <= #1 _rRNW;
	rTC <= #1 _rTC;
	rTD <= #1 _rTD;
	rEP <= #1 _rEP;
	rAttr <= #1 _rAttr;
	rReqLen <= #1 _rReqLen;
	rReqId <= #1 _rReqId;
	rReqTag <= #1 _rReqTag;
	rBE <= #1 _rBE;
	r3DWHeader <= #1 _r3DWHeader;
	rReqData <= #1 _rReqData;
	rReqAddr <= #1 _rReqAddr;
	rQWAReq <= #1 _rQWAReq;
end

always @ (*) begin
	_rReqState = rReqState;
	_rTC = rTC;
	_rTD = rTD;
	_rEP = rEP;
	_rAttr = rAttr;
	_rReqLen = rReqLen;
	_rReqId = rReqId;
	_rReqTag = rReqTag;
	_rBE = rBE;
	_r3DWHeader = r3DWHeader;
	_rReqData = rReqData;
	_rReqAddr = rReqAddr;
	_rReqWen = rReqWen;
	_rRNW = rRNW;
    _rQWAReq = rQWAReq;

	case (rReqState)

	`S_RXENG64_REQ_PARSE : begin // Process DW0, DW1
		_rTC = rDataIn[22:20];
		_rTD = rDataIn[15];
		_rEP = rDataIn[14];
		_rAttr = rDataIn[13:12];
		_rReqLen = rDataIn[9:0];
		_rReqId = rDataIn[63:48];
		_rReqTag = rDataIn[47:40];
		_rBE = rDataIn[35:32];	
		_r3DWHeader = !rDataIn[29];
		_rReqWen = 0;
		// Trigger only set if the packet is valid
		case (rTrigger) 
			3'd0 :		_rReqState = rReqState; 
			3'd1 :		_rReqState = (rLenOneIn ? `S_RXENG64_REQ_MEM_RD_0 : `S_RXENG64_REQ_UNHANDLED);
			3'd2 :		_rReqState = (rLenOneIn ? `S_RXENG64_REQ_MEM_WR_0 : `S_RXENG64_REQ_UNHANDLED);
			default :	_rReqState = `S_RXENG64_REQ_UNHANDLED;
		endcase
	end 

	`S_RXENG64_REQ_UNHANDLED : begin
		if (rValidIn & rLastIn)
			_rReqState = `S_RXENG64_REQ_PARSE;		
	end

	`S_RXENG64_REQ_MEM_RD_0 : begin
		_rReqAddr = (r3DWHeader ? rDataIn[31:2] : rDataIn[63:34]);
		_rRNW = 1;
		_rReqWen = (rValidIn & rLastIn);
		if (rValidIn)
			_rReqState = (rLastIn ? `S_RXENG64_REQ_PARSE : `S_RXENG64_REQ_UNHANDLED);
	end

	`S_RXENG64_REQ_MEM_WR_0 : begin
		_rReqData = rDataIn[63:32];
		_rReqAddr = (r3DWHeader ? rDataIn[31:2] : rDataIn[63:34]);
        _rQWAReq = (~rDataIn[2] & r3DWHeader) | (~r3DWHeader & ~rDataIn[34]);
		_rRNW = 0;
		_rReqWen = (rValidIn & rLastIn);
		if (rValidIn) begin
			_rReqState = (rLastIn ? `S_RXENG64_REQ_PARSE : `S_RXENG64_REQ_MEM_WR_1);
		end
	end

	`S_RXENG64_REQ_MEM_WR_1 : begin
		_rReqData = rDataIn >> ({5'd0,~(rQWAReq | (~wALTERA))} << 5);
		_rReqWen = (rValidIn & rLastIn);
		if (rValidIn)
			_rReqState = (rLastIn ? `S_RXENG64_REQ_PARSE : `S_RXENG64_REQ_UNHANDLED);
	end

	default : begin
		_rReqState = `S_RXENG64_REQ_PARSE;
	end

	endcase
end


// When signaled, start processing the packet, handle cpls and cplds.
always @ (posedge CLK) begin
	rCplState <= #1 (RST ? `S_RXENG64_CPL_PARSE : _rCplState);
	rDataOutEn <= #1 (RST ? 2'd0 : _rDataOutEn);
	rDataOutCount <= #1 (RST ? 2'd0 : _rDataOutCount);
	rDataDone <= #1 (RST ? 1'd0 : _rDataDone);
	rDataErr <= #1 (RST ? 1'd0 : _rDataErr);
	rDataValid <= #1 (RST ? 1'd0 : _rDataValid);
	rCplErr <= #1 _rCplErr;
	rLastCPLD <= #1 _rLastCPLD;
	rDataOut <= #1 _rDataOut;
	rChnlShft <= #1 _rChnlShft;
end

always @ (*) begin
	_rCplState = rCplState;
	_rCplErr = rCplErr;
	_rLastCPLD = rLastCPLD;
	_rDataOut = rDataOut;
	_rDataOutEn = rDataOutEn;
	_rDataOutCount = rDataOutCount;
	_rDataDone = rDataDone;
	_rDataErr = rDataErr;
	_rDataValid = rDataValid;
	_rChnlShft = rChnlShft;
	case (rCplState)

	`S_RXENG64_CPL_PARSE : begin // Process DW0, DW1
		_rDataOutEn = 0;
		_rDataOutCount = 0;
		_rDataDone = 0;
		_rDataErr = 0;
		_rDataValid = 0;
		_rCplErr = (rDataIn[47:45] != 3'b000); // Completion status code
		_rLastCPLD = (rDataIn[43:32] == (rDataIn[9:0]<<2)); // byte_count == length ?
		// Trigger only set if the packet is valid
		case (rTrigger) 
			3'd0 :		_rCplState = rCplState;
			3'd3 :		_rCplState = `S_RXENG64_CPL_NO_DATA;
			3'd4 :		_rCplState = `S_RXENG64_CPL_DATA;
			default :	_rCplState = `S_RXENG64_CPL_WAIT_FOR_END;
		endcase
	end 

	`S_RXENG64_CPL_WAIT_FOR_END : begin // Wait until the end of the TLP
		_rDataOutEn = 0;
		_rDataOutCount = 0;
		_rDataDone = 0;
		_rDataErr = 0;
		_rDataValid = 0;
		if (rValidIn & rLastIn)
			_rCplState = `S_RXENG64_CPL_PARSE;		
	end

	`S_RXENG64_CPL_NO_DATA : begin // Process DW2
		_rChnlShft = rDataIn[15:8]; // Tag is [15:8]
		_rDataValid = rValidIn;
		if (rValidIn) begin
			_rDataOutEn = 0;
			_rDataOutCount = 0;
			_rDataErr = rCplErr;
			_rDataDone = 1;
			_rCplState = (rLastIn ? `S_RXENG64_CPL_PARSE : `S_RXENG64_CPL_WAIT_FOR_END);
		end
	end

	`S_RXENG64_CPL_DATA : begin // Process DW2, DW3
		_rChnlShft = rDataIn[15:8]; // Tag is [15:8]
		_rDataValid = rValidIn;
		_rDataOut = (rDataIn>>32);
		if (rValidIn) begin
			_rDataOutEn = rKeepBothIn & (~rQWACpl | ~wALTERA);
			_rDataOutCount = rKeepBothIn & (~rQWACpl | ~wALTERA);
			_rDataDone = (rCplErr | (rLastIn & rLastCPLD));
			_rDataErr = rCplErr;
			if (rLastIn) // Ends in this packet
				_rCplState = `S_RXENG64_CPL_PARSE;
			else if (rCplErr) // Bad completion code
				_rCplState = `S_RXENG64_CPL_WAIT_FOR_END;
			else // Continues past this packet, send 1 DW now
				_rCplState = `S_RXENG64_CPL_DATA_CONT;
		end
	end

	`S_RXENG64_CPL_DATA_CONT : begin // Process packet until end
		_rDataValid = rValidIn;
		_rDataOut = rDataIn;
		if (rValidIn) begin // Process and write until last packet
			_rDataOutEn = {(!rLastIn | rKeepBothIn), 1'b1};
			_rDataOutCount = (2'd1<<(!rLastIn | rKeepBothIn));
			_rDataDone = (rLastIn & rLastCPLD);
			_rDataErr = 0;
			_rCplState = (rLastIn ? `S_RXENG64_CPL_PARSE : `S_RXENG64_CPL_DATA_CONT);
		end
	end

	endcase
end


endmodule
