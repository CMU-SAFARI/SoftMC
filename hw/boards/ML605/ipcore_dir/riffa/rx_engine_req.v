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
// Filename:			rx_engine_req.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Handles write and read memory requests for the rx_engine
// by queuing them up and processing in a separate state machine. This allows
// the rx_engine to process incoming TLPs at line rate. 
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
// Additional Comments:
//-----------------------------------------------------------------------------
`define S_RXENGREQ_IDLE		2'd0
`define S_RXENGREQ_PAUSE	2'd1
`define S_RXENGREQ_ASSIGN	2'd2
`define S_RXENGREQ_WAIT		2'd3

module rx_engine_req #(
	parameter C_NUM_CHNL = 4'd12,
	// Local parameters
	parameter C_FIFO_DEPTH = 6*C_NUM_CHNL,
	parameter C_WR_DATA_WIDTH = 30+32, // 62
	parameter C_RD_DATA_WIDTH = 30+10+4+3+1+1+2+16+8, // 75
	parameter C_FIFO_WIDTH = (C_WR_DATA_WIDTH > C_RD_DATA_WIDTH ? C_WR_DATA_WIDTH : C_RD_DATA_WIDTH) + 1
)
(
	input CLK,
	input RST,

	// Received read/write memory requests
	output REQ_WR,				// Memory write request
	input REQ_WR_DONE,			// Memory write completed
	output REQ_RD,				// Memory read request
	input REQ_RD_DONE,			// Memory read complete
	output [9:0] REQ_LEN,		// Memory length (1DW)
	output [29:0] REQ_ADDR,		// Memory address (bottom 2 bits are always 00)
	output [31:0] REQ_DATA,		// Memory write data
	output [3:0] REQ_BE,		// Memory byte enables
	output [2:0] REQ_TC,		// Memory traffic class
	output REQ_TD,				// Memory packet digest
	output REQ_EP,      		// Memory poisoned packet
	output [1:0] REQ_ATTR,		// Memory packet relaxed ordering, no snoop
	output [15:0] REQ_ID,		// Memory requestor id
	output [7:0] REQ_TAG,		// Memory packet tag

	// Memory requests 
	input WEN,					// Memory request write enable
	input RNW,					// Memory read (not write) request
	input [9:0] LEN,			// Memory length (1DW)
	input [29:0] ADDR,			// Memory address (bottom 2 bits are always 00)
	input [31:0] DATA,			// Memory write data
	input [3:0] BE,				// Memory byte enables
	input [2:0] TC,				// Memory traffic class
	input TD,					// Memory packet digest
	input EP,      				// Memory poisoned packet
	input [1:0] ATTR,			// Memory packet relaxed ordering, no snoop
	input [15:0] ID,			// Memory requestor id
	input [7:0] TAG				// Memory packet tag

);

`include "common_functions.v"

reg		[1:0]						rState=`S_RXENGREQ_IDLE, _rState=`S_RXENGREQ_IDLE;
reg									rRd=0, _rRd=0;
reg									rWr=0, _rWr=0;
reg									rRen=0, _rRen=0;
reg		[29:0]						rAddr=0, _rAddr=0;
reg		[31:0]						rData=0, _rData=0;
reg		[2:0]						rTC=0, _rTC=0;
reg									rTD=0, _rTD=0;
reg									rEP=0, _rEP=0;
reg		[1:0]						rAttr=0, _rAttr=0;
reg		[9:0]						rLen=0, _rLen=0;
reg		[15:0]						rId=0, _rId=0;
reg		[7:0]						rTag=0, _rTag=0;
reg		[3:0]						rBE=0, _rBE=0;
wire								wFifoEmpty;
wire	[C_FIFO_WIDTH-1:0]			wDataOut;
wire	[C_FIFO_WIDTH-1:0]			wDataIn = ({LEN, BE, TC, TD, EP, ATTR, ID, TAG, ADDR, RNW, DATA, RNW})>>(33*RNW);


assign REQ_RD = rRd;
assign REQ_WR = rWr;
assign REQ_ADDR = rAddr;
assign REQ_DATA = rData;
assign REQ_BE = rBE;
assign REQ_TC = rTC;
assign REQ_TD = rTD;
assign REQ_EP = rEP;
assign REQ_ATTR = rAttr;
assign REQ_LEN = rLen;
assign REQ_ID = rId;
assign REQ_TAG = rTag;


// FIFO for storing data for read/write requests.
(* RAM_STYLE="DISTRIBUTED" *)
sync_fifo #(.C_WIDTH(C_FIFO_WIDTH), .C_DEPTH(C_FIFO_DEPTH)) fifo (
	.RST(RST),
	.CLK(CLK),
	.WR_EN(WEN),
	.WR_DATA(wDataIn),
	.FULL(),
	.COUNT(),
	.RD_EN(rRen),
	.RD_DATA(wDataOut),
	.EMPTY(wFifoEmpty)
);


// Process writes and reads when the FIFOs are not empty. This will always 
// process writes over reads.
always @ (posedge CLK) begin
	rState <= #1 (RST ? `S_RXENGREQ_IDLE : _rState);
	rRd <= #1 (RST ? 1'd0 : _rRd);
	rWr <= #1 (RST ? 1'd0 : _rWr);
	rRen <= #1 (RST ? 1'd0 : _rRen);
	rAddr <= #1 _rAddr;
	rData <= #1 _rData;
	rLen <= #1 _rLen;
	rBE <= #1 _rBE;
	rTC <= #1 _rTC;
	rTD <= #1 _rTD;
	rEP <= #1 _rEP;
	rAttr <= #1 _rAttr;
	rId <= #1 _rId;
	rTag <= #1 _rTag;
end

always @ (*) begin
	_rState = rState;
	_rRd = rRd;
	_rWr = rWr;
	_rRen = rRen;
	_rAddr = rAddr;
	_rData = rData;
	_rLen = rLen;
	_rBE = rBE;
	_rTC = rTC;
	_rTD = rTD;
	_rEP = rEP;
	_rAttr = rAttr;
	_rId = rId;
	_rTag = rTag;
	
	case (rState)
	
	`S_RXENGREQ_IDLE: begin
		if (!wFifoEmpty) begin
			_rRen = 1;
			_rState = `S_RXENGREQ_PAUSE;
		end
	end

	`S_RXENGREQ_PAUSE: begin
		_rRen = 0;
		_rState = `S_RXENGREQ_ASSIGN;
	end

	`S_RXENGREQ_ASSIGN: begin
		_rWr = !wDataOut[0]; // !RNW
		_rRd = wDataOut[0]; // RNW
		if (wDataOut[0]) begin
			{_rLen, _rBE, _rTC, _rTD, _rEP, _rAttr, _rId, _rTag, _rAddr} = wDataOut[C_FIFO_WIDTH-1:1];
		end
		else begin
			_rAddr = wDataOut[63:34];
			_rData = wDataOut[32:1];
		end		
		_rState = `S_RXENGREQ_WAIT;
	end

	`S_RXENGREQ_WAIT: begin
		if (rWr & REQ_WR_DONE) begin
			_rWr = 0;
			_rState = `S_RXENGREQ_IDLE;
		end
		else if (rRd & REQ_RD_DONE) begin
			_rRd = 0;
			_rState = `S_RXENGREQ_IDLE;
		end
	end
	
	endcase
end


endmodule
