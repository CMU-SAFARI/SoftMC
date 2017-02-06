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
// Filename:			sg_list_reader_128.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Reads data from the scatter gather list buffer.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------
`define S_SGR128_RD_0		1'b1
`define S_SGR128_RD_WAIT	1'b0

`define S_SGR128_CAP_0		1'b0
`define S_SGR128_CAP_RDY	1'b1

module sg_list_reader_128 #(
	parameter C_DATA_WIDTH = 9'd128
)
(
	input CLK,
	input RST,

	input [C_DATA_WIDTH-1:0] BUF_DATA,	// Scatter gather buffer data 
	input BUF_DATA_EMPTY,				// Scatter gather buffer data empty
	output BUF_DATA_REN,				// Scatter gather buffer data read enable

	output VALID,						// Scatter gather element data is valid
	output EMPTY,						// Scatter gather elements empty
	input REN,							// Scatter gather element data read enable
	output [63:0] ADDR,					// Scatter gather element address
	output [31:0] LEN					// Scatter gather element length (in words)
);

(* syn_encoding = "user" *)
(* fsm_encoding = "user" *)
reg							rRdState=`S_SGR128_RD_0, _rRdState=`S_SGR128_RD_0;

(* syn_encoding = "user" *)
(* fsm_encoding = "user" *)
reg							rCapState=`S_SGR128_CAP_0, _rCapState=`S_SGR128_CAP_0;
reg		[C_DATA_WIDTH-1:0]	rData={C_DATA_WIDTH{1'd0}}, _rData={C_DATA_WIDTH{1'd0}};
reg		[63:0]				rAddr=64'd0, _rAddr=64'd0;
reg		[31:0]				rLen=0, _rLen=0;
reg							rFifoValid=0, _rFifoValid=0;
reg							rDataValid=0, _rDataValid=0;


assign BUF_DATA_REN = rRdState; // Not S_SGR128_RD_WAIT
assign VALID = rCapState; // S_SGR128_CAP_RDY
assign EMPTY = (BUF_DATA_EMPTY & rRdState); // Not S_SGR128_RD_WAIT
assign ADDR = rAddr;
assign LEN = rLen;


// Capture address and length as it comes out of the FIFO
always @ (posedge CLK) begin
	rRdState <= #1 (RST ? `S_SGR128_RD_0 : _rRdState);
	rCapState <= #1 (RST ? `S_SGR128_CAP_0 : _rCapState);
	rData <= #1 _rData;
	rFifoValid <= #1 (RST ? 1'd0 : _rFifoValid);
	rDataValid <= #1 (RST ? 1'd0 : _rDataValid);
	rAddr <= #1 _rAddr;
	rLen <= #1 _rLen;
end

always @ (*) begin
	_rRdState = rRdState;
	_rCapState = rCapState;
	_rAddr = rAddr;
	_rLen = rLen;
	_rData = BUF_DATA;
	_rFifoValid = (BUF_DATA_REN & !BUF_DATA_EMPTY);
	_rDataValid = rFifoValid;

	case (rCapState)
	
	`S_SGR128_CAP_0: begin
		if (rDataValid) begin
			_rAddr = rData[63:0];
			_rLen = rData[95:64];
			_rCapState = `S_SGR128_CAP_RDY;
		end
	end

	`S_SGR128_CAP_RDY: begin
		if (REN)
			_rCapState = `S_SGR128_CAP_0;
	end
	
	endcase

	case (rRdState)

	`S_SGR128_RD_0: begin // Read from the sg data FIFO
		if (!BUF_DATA_EMPTY)
			_rRdState = `S_SGR128_RD_WAIT;
	end

	`S_SGR128_RD_WAIT: begin // Wait for the data to be consumed
		if (REN)
			_rRdState = `S_SGR128_RD_0;
	end
	
	endcase
end

endmodule
