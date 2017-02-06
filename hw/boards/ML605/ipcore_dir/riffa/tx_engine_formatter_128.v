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
// Filename:			tx_engine_formatter_128.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Formats read and write request data into PCI packets.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
// Additional Comments: Very good PCIe header reference:
// http://www.pzk-agro.com/0321156307_ch04lev1sec5.html#ch04lev4sec14
//-----------------------------------------------------------------------------
`define FMT_TXENGFMTR128_WR32	7'b10_00000
`define FMT_TXENGFMTR128_RD32	7'b00_00000
`define FMT_TXENGFMTR128_WR64	7'b11_00000
`define FMT_TXENGFMTR128_RD64	7'b01_00000

`define S_TXENGFMTR128_IDLE		1'b0
`define S_TXENGFMTR128_WR		1'b1

module tx_engine_formatter_128 #(
	parameter C_PCI_DATA_WIDTH = 9'd128,
	// Local parameters
	parameter C_TRAFFIC_CLASS = 3'b0,
	parameter C_RELAXED_ORDER = 1'b0,
	parameter C_NO_SNOOP = 1'b0
)
(
	input CLK,
	input RST,
	input [15:0] CONFIG_COMPLETER_ID,

	input VALID,		 					// Are input parameters valid?
	input WNR,		 						// Is a write request, not a read?
	input [7:0] TAG,		 				// External tag
	input [3:0] CHNL,		 				// Internal tag (just channel portion)
	input [61:0] ADDR,		 				// Request address
	input ADDR_64,		 					// Request address is 64 bit
	input [9:0] LEN,		 				// Request length
	input LEN_ONE,		 					// Request length equals 1
	input [C_PCI_DATA_WIDTH-1:0] WR_DATA,	// Request data, timed to arrive accordingly

	output [C_PCI_DATA_WIDTH-1:0] OUT_DATA,	// Formatted PCI packet data
	output OUT_DATA_WEN 					// Write enable for formatted packet data
);

reg									rState=`S_TXENGFMTR128_IDLE, _rState=`S_TXENGFMTR128_IDLE;
reg									rAddr64=0, _rAddr64=0;
reg		[C_PCI_DATA_WIDTH-1:0]		rData={C_PCI_DATA_WIDTH{1'd0}}, _rData={C_PCI_DATA_WIDTH{1'd0}};
reg		[C_PCI_DATA_WIDTH-1:0]		rPrevData={C_PCI_DATA_WIDTH{1'd0}}, _rPrevData={C_PCI_DATA_WIDTH{1'd0}};
reg									rDataWen=0, _rDataWen=0;
reg		[9:0]						rLen=0, _rLen=0;
reg									rDone=0, _rDone=0;


assign OUT_DATA = rData;
assign OUT_DATA_WEN = rDataWen;


// Format read and write requests into PCIe packets.
wire [63:0] wHdrData = ({WR_DATA[31:0], ADDR[29:0], 2'b00, ADDR[61:30]})>>(32*(!ADDR_64));
wire [C_PCI_DATA_WIDTH-1:0] wWrData = ({WR_DATA[31:0], rPrevData})>>(32*(!rAddr64));

always @ (posedge CLK) begin
	rState <= #1 (RST ? `S_TXENGFMTR128_IDLE : _rState);
	rDataWen <= #1 (RST ? 1'd0 : _rDataWen);
	rData <= #1 _rData;
	rLen <= #1 _rLen;
	rAddr64 <= #1 _rAddr64;
	rPrevData <= #1 _rPrevData;
	rDone <= #1 _rDone;
end

always @ (*) begin
	_rState = rState;
	_rLen = rLen;
	_rData = rData;
	_rDataWen = rDataWen;
	_rPrevData = WR_DATA;
	_rAddr64 = rAddr64;
	case (rState) 

	`S_TXENGFMTR128_IDLE : begin // FIFO data should be available now (if it's a write)
		_rLen = LEN - !ADDR_64; // Subtract 1 for 32 bit (HDR has one)
		_rAddr64 = ADDR_64;
		_rData = {wHdrData,														// DW3, DW2
					CONFIG_COMPLETER_ID[15:3], 3'b0, TAG,
					(LEN_ONE ? 4'b0 : 4'b1111), 4'b1111,						// DW1
					1'b0, {WNR, ADDR_64, 5'd0}, 1'b0, C_TRAFFIC_CLASS, CHNL, 1'b0, 1'b0, // Use the reserved 4 bits before traffic class to hide the internal tag 
					C_RELAXED_ORDER, C_NO_SNOOP, 2'b0, LEN};					// DW0
		_rDataWen = VALID;
		_rDone = (LEN <= {1'b1, 1'b0, !ADDR_64});
		_rState = (VALID & WNR & (ADDR_64 | !LEN_ONE) ? `S_TXENGFMTR128_WR : `S_TXENGFMTR128_IDLE);
	end

	`S_TXENGFMTR128_WR : begin
		_rLen = rLen - 3'd4;
		_rDone = (rLen <= 4'd8);
		_rData = wWrData;
		_rState = (rDone ? `S_TXENGFMTR128_IDLE : `S_TXENGFMTR128_WR);
	end

	endcase
end

endmodule
