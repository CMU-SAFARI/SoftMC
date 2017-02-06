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
// Filename:			tx_port_buffer_32.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Wraps a FIFO for saving channel data and provides a 
// registered read output. Data is available 3 cycles after RD_EN is asserted 
// (not 1, like a traditional FIFO).
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------

module tx_port_buffer_32 #(
	parameter C_FIFO_DATA_WIDTH = 9'd32,
	parameter C_FIFO_DEPTH = 512,
	// Local parameters
	parameter C_FIFO_DEPTH_WIDTH = clog2((2**clog2(C_FIFO_DEPTH))+1)
)
(
	input RST,
	input CLK,

	input [C_FIFO_DATA_WIDTH-1:0] WR_DATA,		// Input data
	input WR_EN,								// Input data write enable
	output [C_FIFO_DEPTH_WIDTH-1:0] WR_COUNT,	// Input data FIFO is full

	output [C_FIFO_DATA_WIDTH-1:0] RD_DATA,		// Output data
	input RD_EN									// Output data read enable
);

`include "common_functions.v"

reg 								rFifoRdEn=0, _rFifoRdEn=0;
reg		[C_FIFO_DATA_WIDTH-1:0]		rFifoData={C_FIFO_DATA_WIDTH{1'd0}}, _rFifoData={C_FIFO_DATA_WIDTH{1'd0}};
wire	[C_FIFO_DATA_WIDTH-1:0]		wFifoData;

assign RD_DATA = rFifoData;


// Buffer the input signals that come from outside the tx_port.
always @ (posedge CLK) begin
	rFifoRdEn <= #1 (RST ? 1'd0 : _rFifoRdEn);
end

always @ (*) begin
	_rFifoRdEn = RD_EN;
end


// FIFO for storing data from the channel.
(* RAM_STYLE="BLOCK" *)
sync_fifo #(.C_WIDTH(C_FIFO_DATA_WIDTH), .C_DEPTH(C_FIFO_DEPTH), .C_PROVIDE_COUNT(1)) fifo (
	.CLK(CLK),
	.RST(RST),
	.WR_EN(WR_EN),
	.WR_DATA(WR_DATA),
	.FULL(),
	.COUNT(WR_COUNT),
	.RD_EN(rFifoRdEn),
	.RD_DATA(wFifoData),
	.EMPTY()
);


// Buffer data from the FIFO.
always @ (posedge CLK) begin
	rFifoData <= #1 _rFifoData;
end

always @ (*) begin
	_rFifoData = wFifoData;
end


endmodule
