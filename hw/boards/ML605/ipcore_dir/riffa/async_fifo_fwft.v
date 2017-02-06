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
// Filename:			async_fifo_fwft.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			An asynchronous capable parameterized FIFO. As with all
// first word fall through FIFOs, the RD_DATA will be valid when RD_EMPTY is 
// low. Asserting RD_EN will consume the current RD_DATA value and cause the 
// next value (if it exists) to appear on RD_DATA on the following cycle. Be sure 
// to check if RD_EMPTY is low each cycle to determine if RD_DATA is valid.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------

module async_fifo_fwft #(
	parameter C_WIDTH = 32,	// Data bus width
	parameter C_DEPTH = 1024,	// Depth of the FIFO
	// Local parameters
	parameter C_REAL_DEPTH = 2**clog2(C_DEPTH),
	parameter C_DEPTH_BITS = clog2s(C_REAL_DEPTH),
	parameter C_DEPTH_P1_BITS = clog2s(C_REAL_DEPTH+1)
)
(
	input RD_CLK,							// Read clock
	input RD_RST,							// Read synchronous reset
	input WR_CLK,						 	// Write clock
	input WR_RST,							// Write synchronous reset
	input [C_WIDTH-1:0] WR_DATA, 			// Write data input (WR_CLK)
	input WR_EN, 							// Write enable, high active (WR_CLK)
	output [C_WIDTH-1:0] RD_DATA, 			// Read data output (RD_CLK)
	input RD_EN,							// Read enable, high active (RD_CLK)
	output WR_FULL, 						// Full condition (WR_CLK)
	output RD_EMPTY 						// Empty condition (RD_CLK)
);

`include "common_functions.v"

reg		[C_WIDTH-1:0]			rData=0;
reg		[C_WIDTH-1:0]			rCache=0;
reg		[1:0]					rCount=0;
reg								rFifoDataValid=0;
reg								rDataValid=0;
reg								rCacheValid=0;
wire	[C_WIDTH-1:0]			wData;
wire							wEmpty;
wire							wRen = RD_EN || (rCount < 2'd2);


assign RD_DATA = rData;
assign RD_EMPTY = !rDataValid;


// Wrapped non-FWFT FIFO (synthesis attributes applied to this module will
// determine the memory option).
async_fifo #(.C_WIDTH(C_WIDTH), .C_DEPTH(C_DEPTH)) fifo (
	.WR_CLK(WR_CLK),
	.WR_RST(WR_RST),
	.RD_CLK(RD_CLK),
	.RD_RST(RD_RST),
	.WR_EN(WR_EN),
	.WR_DATA(WR_DATA),
	.WR_FULL(WR_FULL),
	.RD_EN(wRen),
	.RD_DATA(wData),
	.RD_EMPTY(wEmpty)
);

always @ (posedge RD_CLK) begin
	if (RD_RST) begin
		rCount <= #1 0;
		rDataValid <= #1 0;
		rCacheValid <= #1 0;
		rFifoDataValid <= #1 0;
	end
	else begin
		// Keep track of the count
		rCount <= #1 rCount + (wRen & !wEmpty) - (!RD_EMPTY & RD_EN);

		// Signals when wData from FIFO is valid
		rFifoDataValid <= #1 (wRen & !wEmpty);

		// Keep rData up to date
		if (rFifoDataValid) begin
			if (RD_EN | !rDataValid) begin
				rData <= #1 wData;
				rDataValid <= #1 1'd1;
				rCacheValid <= #1 1'd0;
			end
			else begin
				rCacheValid <= #1 1'd1;
			end
			rCache  <= #1 wData;
		end
		else begin
			if (RD_EN | !rDataValid) begin
				rData <= #1 rCache;
				rDataValid <= #1 rCacheValid;
				rCacheValid <= #1 1'd0;
			end
		end
	end
end
 
endmodule
 