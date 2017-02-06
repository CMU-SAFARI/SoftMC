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
// Filename:			fifo_packer_64.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Packs 32 or 64 bit received data into a 64 bit wide FIFO. 
// Assumes the FIFO always has room to accommodate the data.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
// Additional Comments: 
//-----------------------------------------------------------------------------

module fifo_packer_64 (
	input CLK,
	input RST,
	input [63:0] DATA_IN,		// Incoming data
	input [1:0] DATA_IN_EN,		// Incoming data enable
	input DATA_IN_DONE,			// Incoming data packet end
	input DATA_IN_ERR,			// Incoming data error
	input DATA_IN_FLUSH,		// End of incoming data
	output [63:0] PACKED_DATA,	// Outgoing data
	output PACKED_WEN,			// Outgoing data write enable
	output PACKED_DATA_DONE,	// End of outgoing data packet
	output PACKED_DATA_ERR,		// Error in outgoing data
	output PACKED_DATA_FLUSHED	// End of outgoing data
);

reg		[1:0]		rPackedCount=0, _rPackedCount=0;
reg					rPackedDone=0, _rPackedDone=0;
reg					rPackedErr=0, _rPackedErr=0;
reg					rPackedFlush=0, _rPackedFlush=0;
reg					rPackedFlushed=0, _rPackedFlushed=0;
reg		[95:0]		rPackedData=96'd0, _rPackedData=96'd0;
reg		[63:0]		rDataIn=64'd0, _rDataIn=64'd0;
reg		[1:0]		rDataInEn=0, _rDataInEn=0;
reg		[63:0]		rDataMasked=64'd0, _rDataMasked=64'd0;
reg		[1:0]		rDataMaskedEn=0, _rDataMaskedEn=0;


assign PACKED_DATA = rPackedData[63:0];
assign PACKED_WEN = rPackedCount[1];
assign PACKED_DATA_DONE = rPackedDone;
assign PACKED_DATA_ERR = rPackedErr;
assign PACKED_DATA_FLUSHED = rPackedFlushed;


// Buffers input data until 2 words are available, then writes 2 words out.
wire [63:0] wMask = {64{1'b1}}<<(32*rDataInEn);
wire [63:0]	wDataMasked = ~wMask & rDataIn;
always @ (posedge CLK) begin
	rPackedCount <= #1 (RST ? 2'd0 : _rPackedCount);
	rPackedDone <= #1 (RST ? 1'd0 : _rPackedDone);
	rPackedErr <= #1 (RST ? 1'd0 : _rPackedErr);
	rPackedFlush <= #1 (RST ? 1'd0 : _rPackedFlush);
	rPackedFlushed <= #1 (RST ? 1'd0 : _rPackedFlushed);
	rPackedData <= #1 (RST ? 96'd0 : _rPackedData);
	rDataIn <= #1 _rDataIn;
	rDataInEn <= #1 (RST ? 2'd0 : _rDataInEn);
	rDataMasked <= #1 _rDataMasked;
	rDataMaskedEn <= #1 (RST ? 2'd0 : _rDataMaskedEn);
end

always @ (*) begin
	// Buffer and mask the input data.
	_rDataIn = DATA_IN;
	_rDataInEn = DATA_IN_EN;
	_rDataMasked = wDataMasked;
	_rDataMaskedEn = rDataInEn;

	// Count what's in our buffer. When we reach 2 words, 2 words will be written
	// out. If flush is requested, write out whatever remains.
	if (rPackedFlush && rPackedCount[0])
		_rPackedCount = 2;
	else
		_rPackedCount = rPackedCount + rDataMaskedEn - {rPackedCount[1], 1'd0};
	
	// Shift data into and out of our buffer as we receive and write out data.
	if (rDataMaskedEn != 2'd0)
		_rPackedData = ((rPackedData>>(32*{rPackedCount[1], 1'd0})) | (rDataMasked<<(32*rPackedCount[0])));
	else
		_rPackedData = (rPackedData>>(32*{rPackedCount[1], 1'd0}));

	// Track done/error/flush signals.
	_rPackedDone = DATA_IN_DONE;
	_rPackedErr = DATA_IN_ERR;
	_rPackedFlush = DATA_IN_FLUSH;
	_rPackedFlushed = rPackedFlush;
end



endmodule
