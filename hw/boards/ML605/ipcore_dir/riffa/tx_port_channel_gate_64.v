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
// Filename:			tx_port_channel_gate_64.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Captures transaction open/close events as well as data
// and passes it to the RD_CLK domain through the async_fifo. CHNL_TX_DATA_REN can
// only be high after CHNL_TX goes high and after the CHNL_TX_ACK pulse. When
// CHNL_TX drops, the channel closes (until the next transaction -- signaled by
// CHNL_TX going up again).
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------
`define S_TXPORTGATE64_IDLE		2'b00
`define S_TXPORTGATE64_OPENING	2'b01
`define S_TXPORTGATE64_OPEN		2'b10
`define S_TXPORTGATE64_CLOSED	2'b11

module tx_port_channel_gate_64 #(
	parameter C_DATA_WIDTH = 9'd64,
	// Local parameters
	parameter C_FIFO_DEPTH = 8,
	parameter C_FIFO_DATA_WIDTH = C_DATA_WIDTH+1
)
(
	input RST,

	input RD_CLK,							// FIFO read clock
	output [C_FIFO_DATA_WIDTH-1:0] RD_DATA,	// FIFO read data
	output RD_EMPTY,						// FIFO is empty
	input RD_EN,							// FIFO read enable

	input CHNL_CLK,							// Channel write clock
	input CHNL_TX,							// Channel write receive signal
	output CHNL_TX_ACK,						// Channel write acknowledgement signal
	input CHNL_TX_LAST,						// Channel last write
	input [31:0] CHNL_TX_LEN,				// Channel write length (in 32 bit words)
	input [30:0] CHNL_TX_OFF,				// Channel write offset
	input [C_DATA_WIDTH-1:0] CHNL_TX_DATA,	// Channel write data
	input CHNL_TX_DATA_VALID,				// Channel write data valid
	output CHNL_TX_DATA_REN					// Channel write data has been recieved
);

(* syn_encoding = "user" *)
(* fsm_encoding = "user" *)
reg		[1:0]					rState=`S_TXPORTGATE64_IDLE, _rState=`S_TXPORTGATE64_IDLE;
reg								rFifoWen=0, _rFifoWen=0;
reg		[C_FIFO_DATA_WIDTH-1:0]	rFifoData=0, _rFifoData=0;
wire							wFifoFull;

reg								rChnlTx=0, _rChnlTx=0;
reg								rChnlLast=0, _rChnlLast=0;
reg		[31:0]					rChnlLen=0, _rChnlLen=0;
reg		[30:0]					rChnlOff=0, _rChnlOff=0;
reg								rAck=0, _rAck=0;
reg								rPause=0, _rPause=0;
reg								rClosed=0, _rClosed=0;


assign CHNL_TX_ACK = rAck;
assign CHNL_TX_DATA_REN = (rState[1] & !rState[0] & !wFifoFull); // S_TXPORTGATE64_OPEN


// Buffer the input signals that come from outside the tx_port.
always @ (posedge CHNL_CLK) begin
	rChnlTx <= #1 (RST ? 1'd0 : _rChnlTx);
	rChnlLast <= #1 _rChnlLast;
	rChnlLen <= #1 _rChnlLen;
	rChnlOff <= #1 _rChnlOff;
end

always @ (*) begin
	_rChnlTx = CHNL_TX;
	_rChnlLast = CHNL_TX_LAST;
	_rChnlLen = CHNL_TX_LEN;
	_rChnlOff = CHNL_TX_OFF;
end


// FIFO for temporarily storing data from the channel.
(* RAM_STYLE="DISTRIBUTED" *)
async_fifo #(.C_WIDTH(C_FIFO_DATA_WIDTH), .C_DEPTH(C_FIFO_DEPTH)) fifo (
	.WR_CLK(CHNL_CLK),
	.WR_RST(RST),
	.WR_EN(rFifoWen),
	.WR_DATA(rFifoData),
	.WR_FULL(wFifoFull),
	.RD_CLK(RD_CLK),
	.RD_RST(RST),
	.RD_EN(RD_EN),
	.RD_DATA(RD_DATA),
	.RD_EMPTY(RD_EMPTY)
);


// Pass the transaction open event, transaction data, and the transaction
// close event through to the RD_CLK domain via the async_fifo.
always @ (posedge CHNL_CLK) begin
	rState <= #1 (RST ? `S_TXPORTGATE64_IDLE : _rState);
	rFifoWen <= #1 (RST ? 1'd0 : _rFifoWen);
	rFifoData <= #1 _rFifoData;
	rAck <= #1 (RST ? 1'd0 : _rAck);
	rPause <= #1 (RST ? 1'd0 : _rPause);
	rClosed <= #1 (RST ? 1'd0 : _rClosed);
end

always @ (*) begin
	_rState = rState;
	_rFifoWen = rFifoWen;
	_rFifoData = rFifoData;
	_rPause = rPause;
	_rAck = rAck;
	_rClosed = rClosed;
	case (rState)

	`S_TXPORTGATE64_IDLE: begin // Write the len, off, last
		_rPause = 0;
		_rClosed = 0;
		if (!wFifoFull) begin
			_rAck = rChnlTx;
			_rFifoWen = rChnlTx;
			_rFifoData = {1'd1, rChnlLen, rChnlOff, rChnlLast};
			if (rChnlTx)
				_rState = `S_TXPORTGATE64_OPENING;
		end
	end

	`S_TXPORTGATE64_OPENING: begin // Write the len, off, last (again)
		_rAck = 0;
		_rClosed = (rClosed | !rChnlTx);
		if (!wFifoFull) begin
			if (rClosed | !rChnlTx)
				_rState = `S_TXPORTGATE64_CLOSED;
			else
				_rState = `S_TXPORTGATE64_OPEN;
		end
	end

	`S_TXPORTGATE64_OPEN: begin // Copy channel data into the FIFO
		if (!wFifoFull) begin
			_rFifoWen = CHNL_TX_DATA_VALID; 	// CHNL_TX_DATA_VALID & CHNL_TX_DATA should really be buffered
			_rFifoData = {1'd0, CHNL_TX_DATA};	// but the VALID+REN model seem to make this difficult.
		end
		if (!rChnlTx)
			_rState = `S_TXPORTGATE64_CLOSED;
	end
	
	`S_TXPORTGATE64_CLOSED: begin // Write the end marker (twice)
		if (!wFifoFull) begin
			_rPause = 1;
			_rFifoWen = 1;
			_rFifoData = {1'd1, {C_DATA_WIDTH{1'd0}}};
			if (rPause)
			_rState = `S_TXPORTGATE64_IDLE;
		end
	end
	
	endcase	
end


endmodule
