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
// Filename:			tx_port_64.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Receives data from the tx_engine and buffers the input 
//						for the RIFFA channel.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------

module tx_port_64 #(
	parameter C_DATA_WIDTH = 9'd64,
	parameter C_FIFO_DEPTH = 512,
	// Local parameters
	parameter C_FIFO_DEPTH_WIDTH = clog2((2**clog2(C_FIFO_DEPTH))+1)
)
(
	input CLK,
	input RST,
	input [2:0] CONFIG_MAX_PAYLOAD_SIZE,	// Maximum write payload: 000=128B, 001=256B, 010=512B, 011=1024B
	
	output TXN,								// Write transaction notification
	input TXN_ACK,							// Write transaction acknowledged
	output [31:0] TXN_LEN,					// Write transaction length
	output [31:0] TXN_OFF_LAST,				// Write transaction offset/last
	output [31:0] TXN_DONE_LEN,				// Write transaction actual transfer length
	output TXN_DONE,						// Write transaction done
	input TXN_DONE_ACK,						// Write transaction actual transfer length read

	input [C_DATA_WIDTH-1:0] SG_DATA,		// Scatter gather data 
	input SG_DATA_EMPTY,					// Scatter gather buffer empty
	output SG_DATA_REN,						// Scatter gather data read enable
	output SG_RST,							// Scatter gather reset
	input SG_ERR,							// Scatter gather read encountered an error
	
	output TX_REQ,							// Outgoing write request
	input TX_REQ_ACK,						// Outgoing write request acknowledged
	output [63:0] TX_ADDR,					// Outgoing write high address
	output [9:0] TX_LEN,					// Outgoing write length (in 32 bit words)
	output [C_DATA_WIDTH-1:0] TX_DATA,		// Outgoing write data
	input TX_DATA_REN,						// Outgoing write data read enable
	input TX_SENT,							// Outgoing write complete

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

`include "common_functions.v"

wire								wGateRen;
wire								wGateEmpty;
wire	[C_DATA_WIDTH:0]			wGateData;

wire								wBufWen;
wire	[C_FIFO_DEPTH_WIDTH-1:0]	wBufCount;
wire	[C_DATA_WIDTH-1:0]			wBufData;

wire								wTxn;
wire								wTxnAck;
wire								wTxnLast;
wire	[31:0]						wTxnLen;
wire	[30:0]						wTxnOff;
wire	[31:0]						wTxnWordsRecvd;
wire								wTxnDone;
wire								wTxnErr;

wire								wSgElemRen;
wire								wSgElemRdy;
wire								wSgElemEmpty;
wire	[31:0]						wSgElemLen;
wire	[63:0]						wSgElemAddr;

wire								wTxLast;

reg		[4:0]						rWideRst=0;
reg									rRst=0;


// Generate a wide reset from the input reset.
always @ (posedge CLK) begin
	rRst <= #1 rWideRst[4]; 
	if (RST) 
		rWideRst <= #1 5'b11111;
	else 
		rWideRst <= (rWideRst<<1);
end


// Capture channel transaction open/close events as well as channel data. 
tx_port_channel_gate_64 #(.C_DATA_WIDTH(C_DATA_WIDTH)) gate (
	.RST(rRst),
	.RD_CLK(CLK),
	.RD_DATA(wGateData),
	.RD_EMPTY(wGateEmpty),
	.RD_EN(wGateRen),
	.CHNL_CLK(CHNL_CLK),
	.CHNL_TX(CHNL_TX),
	.CHNL_TX_ACK(CHNL_TX_ACK),
	.CHNL_TX_LAST(CHNL_TX_LAST),
	.CHNL_TX_LEN(CHNL_TX_LEN),
	.CHNL_TX_OFF(CHNL_TX_OFF),
	.CHNL_TX_DATA(CHNL_TX_DATA),
	.CHNL_TX_DATA_VALID(CHNL_TX_DATA_VALID),
	.CHNL_TX_DATA_REN(CHNL_TX_DATA_REN)
);


// Filter transaction events from channel data. Use the events to put only
// the requested amount of data into the port buffer.
tx_port_monitor_64 #(.C_DATA_WIDTH(C_DATA_WIDTH), .C_FIFO_DEPTH(C_FIFO_DEPTH)) monitor (
	.RST(rRst),
	.CLK(CLK),
	.EVT_DATA(wGateData),
	.EVT_DATA_EMPTY(wGateEmpty),
	.EVT_DATA_RD_EN(wGateRen),
	.WR_DATA(wBufData),
	.WR_EN(wBufWen),
	.WR_COUNT(wBufCount),
	.TXN(wTxn),
	.ACK(wTxnAck),
	.LAST(wTxnLast),
	.LEN(wTxnLen),
	.OFF(wTxnOff),
	.WORDS_RECVD(wTxnWordsRecvd),
	.DONE(wTxnDone),
	.TX_ERR(SG_ERR)
);


// Buffer the incoming channel data. Also make sure to discard only as
// much data as is needed for a transfer (which may involve non-integral 
// packets (i.e. reading only 1 word out of the packet).
tx_port_buffer_64 #(.C_FIFO_DATA_WIDTH(C_DATA_WIDTH), .C_FIFO_DEPTH(C_FIFO_DEPTH)) buffer (
	.CLK(CLK),
	.RST(rRst | (TXN_DONE & wTxnErr)),
	.RD_DATA(TX_DATA),
	.RD_EN(TX_DATA_REN),
	.LEN_VALID(TX_REQ_ACK),
	.LEN_LSB(TX_LEN[0]),
	.LEN_LAST(wTxLast),
	.WR_DATA(wBufData),
	.WR_EN(wBufWen),
	.WR_COUNT(wBufCount)
);


// Read the scatter gather buffer address and length, continuously so that
// we have it ready whenever the next buffer is needed.
sg_list_reader_64 #(.C_DATA_WIDTH(C_DATA_WIDTH)) sgListReader (
	.CLK(CLK),
	.RST(rRst | SG_RST),
	.BUF_DATA(SG_DATA),
	.BUF_DATA_EMPTY(SG_DATA_EMPTY),
	.BUF_DATA_REN(SG_DATA_REN),
	.VALID(wSgElemRdy),
	.EMPTY(wSgElemEmpty),
	.REN(wSgElemRen),
	.ADDR(wSgElemAddr),
	.LEN(wSgElemLen)
);


// Controls the flow of request to the tx engine for transfers in a transaction.
tx_port_writer writer (
	.CLK(CLK),
	.RST(rRst),
	.CONFIG_MAX_PAYLOAD_SIZE(CONFIG_MAX_PAYLOAD_SIZE),
	.TXN(TXN),
	.TXN_ACK(TXN_ACK),
	.TXN_LEN(TXN_LEN),
	.TXN_OFF_LAST(TXN_OFF_LAST),
	.TXN_DONE_LEN(TXN_DONE_LEN),
	.TXN_DONE(TXN_DONE),
	.TXN_ERR(wTxnErr),
	.TXN_DONE_ACK(TXN_DONE_ACK),
	.NEW_TXN(wTxn),
	.NEW_TXN_ACK(wTxnAck),
	.NEW_TXN_LAST(wTxnLast),
	.NEW_TXN_LEN(wTxnLen),
	.NEW_TXN_OFF(wTxnOff),
	.NEW_TXN_WORDS_RECVD(wTxnWordsRecvd),
	.NEW_TXN_DONE(wTxnDone),
	.SG_ELEM_ADDR(wSgElemAddr),
	.SG_ELEM_LEN(wSgElemLen),
	.SG_ELEM_RDY(wSgElemRdy),
	.SG_ELEM_EMPTY(wSgElemEmpty),
	.SG_ELEM_REN(wSgElemRen),
	.SG_RST(SG_RST),
	.SG_ERR(SG_ERR),
	.TX_REQ(TX_REQ),
	.TX_REQ_ACK(TX_REQ_ACK),
	.TX_ADDR(TX_ADDR),
	.TX_LEN(TX_LEN),
	.TX_LAST(wTxLast),
	.TX_SENT(TX_SENT)
);

endmodule
