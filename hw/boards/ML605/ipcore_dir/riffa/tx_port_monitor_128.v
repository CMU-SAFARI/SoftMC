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
// Filename:			tx_port_monitor_128.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Detects transaction open/close events from the stream
// of data from the tx_port_channel_gate. Filters out events and passes data
// onto the tx_port_buffer. 
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------
`define S_TXPORTMON128_NEXT		5'b0_0001
`define S_TXPORTMON128_TXN		5'b0_0010
`define S_TXPORTMON128_READ		5'b0_0100
`define S_TXPORTMON128_END_0	5'b0_1000
`define S_TXPORTMON128_END_1	5'b1_0000

module tx_port_monitor_128 #(
	parameter C_DATA_WIDTH = 9'd128,
	parameter C_FIFO_DEPTH = 512,
	// Local parameters
	parameter C_FIFO_DEPTH_THRESH = (C_FIFO_DEPTH - 4),
	parameter C_FIFO_DEPTH_WIDTH = clog2((2**clog2(C_FIFO_DEPTH))+1),
	parameter C_VALID_HIST = 1
)
(
	input RST,
	input CLK,

	input [C_DATA_WIDTH:0] EVT_DATA,			// Event data from tx_port_channel_gate
	input EVT_DATA_EMPTY,						// Event data FIFO is empty
	output EVT_DATA_RD_EN,						// Event data FIFO read enable

	output [C_DATA_WIDTH-1:0] WR_DATA,			// Output data
	output WR_EN,								// Write enable for output data
	input [C_FIFO_DEPTH_WIDTH-1:0] WR_COUNT,	// Output FIFO count

	output TXN,									// Transaction parameters are valid
	input ACK,									// Transaction parameter read, continue
	output LAST,								// Channel last write
	output [31:0] LEN,							// Channel write length (in 32 bit words)
	output [30:0] OFF,							// Channel write offset
	output [31:0] WORDS_RECVD,					// Count of data words received in transaction
	output DONE,								// Transaction is closed

	input TX_ERR								// Transaction encountered an error
);

`include "common_functions.v"

(* syn_encoding = "user" *)
(* fsm_encoding = "user" *)
reg 	[4:0]				rState=`S_TXPORTMON128_NEXT, _rState=`S_TXPORTMON128_NEXT;
reg 						rRead=0, _rRead=0;
reg 	[C_VALID_HIST-1:0]	rDataValid={C_VALID_HIST{1'd0}}, _rDataValid={C_VALID_HIST{1'd0}};
reg 						rEvent=0, _rEvent=0;
reg 	[63:0]				rReadData=64'd0, _rReadData=64'd0;
reg 	[31:0]				rWordsRecvd=0, _rWordsRecvd=0;
reg 	[31:0]				rWordsRecvdAdv=0, _rWordsRecvdAdv=0;
reg 						rAlmostAllRecvd=0, _rAlmostAllRecvd=0;
reg 						rAlmostFull=0, _rAlmostFull=0;
reg 						rLenEQ0Hi=0, _rLenEQ0Hi=0;
reg 						rLenEQ0Lo=0, _rLenEQ0Lo=0;
reg 						rLenLE4Lo=0, _rLenLE4Lo=0;
reg							rTxErr=0, _rTxErr=0;


assign EVT_DATA_RD_EN = rRead;

assign WR_DATA = EVT_DATA[C_DATA_WIDTH-1:0];
assign WR_EN = wPayloadData; // S_TXPORTMON128_READ

assign TXN = rState[1]; // S_TXPORTMON128_TXN
assign LAST = rReadData[0];
assign OFF = rReadData[31:1];
assign LEN = rReadData[63:32];
assign WORDS_RECVD = rWordsRecvd;
assign DONE = !rState[2]; // !S_TXPORTMON128_READ


wire wEventData = (rDataValid[0] & EVT_DATA[C_DATA_WIDTH]);
wire wPayloadData = (rDataValid[0] & !EVT_DATA[C_DATA_WIDTH] & rState[2]); // S_TXPORTMON128_READ
wire wAllWordsRecvd = ((rAlmostAllRecvd | (rLenEQ0Hi & rLenLE4Lo)) & wPayloadData);


// Buffer the input signals that come from outside the tx_port.
always @ (posedge CLK) begin
	rTxErr <= #1 (RST ? 1'd0 : _rTxErr);
end

always @ (*) begin
	_rTxErr = TX_ERR;
end


// Transaction monitoring FSM.
always @ (posedge CLK) begin
	rState <= #1 (RST ? `S_TXPORTMON128_NEXT : _rState);
end

always @ (*) begin
	_rState = rState;
	case (rState)

	`S_TXPORTMON128_NEXT: begin // Read, wait for start of transaction event
		if (rEvent)
			_rState = `S_TXPORTMON128_TXN;
	end

	`S_TXPORTMON128_TXN: begin // Don't read, wait until transaction has been acknowledged
		if (ACK)
			_rState = ((rLenEQ0Hi && rLenEQ0Lo) ? `S_TXPORTMON128_END_0 : `S_TXPORTMON128_READ);
	end

	`S_TXPORTMON128_READ: begin // Continue reading, wait for end of transaction event or all expected data
		if (rEvent)
			_rState = `S_TXPORTMON128_END_1;
		else if (wAllWordsRecvd | rTxErr)
			_rState = `S_TXPORTMON128_END_0;
	end
	
	`S_TXPORTMON128_END_0: begin // Continue reading, wait for first end of transaction event
		if (rEvent)
			_rState = `S_TXPORTMON128_END_1;
	end

	`S_TXPORTMON128_END_1: begin // Continue reading, wait for second end of transaction event
		if (rEvent)
			_rState = `S_TXPORTMON128_NEXT;
	end

	default: begin
		_rState = `S_TXPORTMON128_NEXT;
	end

	endcase	
end


// Manage reading from the FIFO and tracking amounts read.
always @ (posedge CLK) begin
	rRead <= #1 (RST ? 1'd0 : _rRead);
	rDataValid <= #1 (RST ? {C_VALID_HIST{1'd0}} : _rDataValid);
	rEvent <= #1 (RST ? 1'd0 : _rEvent);
	rReadData <= #1 _rReadData;
	rWordsRecvd <= #1 _rWordsRecvd;
	rWordsRecvdAdv <= #1 _rWordsRecvdAdv;
	rAlmostAllRecvd <= #1 _rAlmostAllRecvd;
	rAlmostFull <= #1 _rAlmostFull;
	rLenEQ0Hi <= #1 _rLenEQ0Hi;
	rLenEQ0Lo <= #1 _rLenEQ0Lo;
	rLenLE4Lo <= #1 _rLenLE4Lo;
end

always @ (*) begin
	// Don't get to the full point in the output FIFO
	_rAlmostFull = (WR_COUNT >= C_FIFO_DEPTH_THRESH);

	// Track read history so we know when data is valid
	_rDataValid = ((rDataValid<<1) | (rRead & !EVT_DATA_EMPTY));

	// Read until we get a (valid) event
	_rRead = (!rState[1] & !wEventData & !rAlmostFull); // !S_TXPORTMON128_TXN

	// Track detected events
	_rEvent = wEventData;

	// Save event data when valid
	if (wEventData)
		_rReadData = EVT_DATA[63:0];
	else
		_rReadData = rReadData;
	
	// If LEN == 0, we don't want to send any data to the output
	_rLenEQ0Hi = (LEN[31:16] == 16'd0);
	_rLenEQ0Lo = (LEN[15:0] == 16'd0);

	// If LEN <= 4, we want to trigger the almost all received flag
	_rLenLE4Lo = (LEN[15:0] <= 16'd4);
	
	// Count received non-event data
	_rWordsRecvd = (ACK ? 0 : rWordsRecvd + (wPayloadData<<2));
	_rWordsRecvdAdv = (ACK ? 2*(C_DATA_WIDTH/32) : rWordsRecvdAdv + (wPayloadData<<2));
	_rAlmostAllRecvd = ((rWordsRecvdAdv >= LEN) && wPayloadData);
end


endmodule
