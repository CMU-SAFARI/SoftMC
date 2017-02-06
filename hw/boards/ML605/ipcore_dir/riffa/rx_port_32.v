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
// Filename:			rx_port_32.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Receives data from the rx_engine and buffers the output 
//						for the RIFFA channel.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------
module rx_port_32 #(
	parameter C_DATA_WIDTH = 9'd32,
	parameter C_MAIN_FIFO_DEPTH = 1024,
	parameter C_SG_FIFO_DEPTH = 512,
	parameter C_MAX_READ_REQ = 2,					// Max read: 000=128B, 001=256B, 010=512B, 011=1024B, 100=2048B, 101=4096B
	// Local parameters
	parameter C_DATA_WORD_WIDTH = clog2((C_DATA_WIDTH/32)+1),
	parameter C_MAIN_FIFO_DEPTH_WIDTH = clog2((2**clog2(C_MAIN_FIFO_DEPTH))+1),
	parameter C_SG_FIFO_DEPTH_WIDTH = clog2((2**clog2(C_SG_FIFO_DEPTH))+1)
)
(
	input CLK,
	input RST,
	input [2:0] CONFIG_MAX_READ_REQUEST_SIZE,				// Maximum read payload: 000=128B, 001=256B, 010=512B, 011=1024B, 100=2048B, 101=4096B

	output SG_RX_BUF_RECVD,							// Scatter gather RX buffer completely read (ready for next if applicable)
	input [31:0] SG_RX_BUF_DATA,					// Scatter gather RX buffer data
	input SG_RX_BUF_LEN_VALID,						// Scatter gather RX buffer length valid
	input SG_RX_BUF_ADDR_HI_VALID,					// Scatter gather RX buffer high address valid
	input SG_RX_BUF_ADDR_LO_VALID,					// Scatter gather RX buffer low address valid

	output SG_TX_BUF_RECVD,							// Scatter gather TX buffer completely read (ready for next if applicable)
	input [31:0] SG_TX_BUF_DATA,					// Scatter gather TX buffer data
	input SG_TX_BUF_LEN_VALID,						// Scatter gather TX buffer length valid
	input SG_TX_BUF_ADDR_HI_VALID,					// Scatter gather TX buffer high address valid
	input SG_TX_BUF_ADDR_LO_VALID,					// Scatter gather TX buffer low address valid

	output [C_DATA_WIDTH-1:0] SG_DATA,				// Scatter gather TX buffer data
	output SG_DATA_EMPTY,							// Scatter gather TX buffer data empty
	input SG_DATA_REN,								// Scatter gather TX buffer data read enable
	input SG_RST,									// Scatter gather TX buffer data reset
	output SG_ERR,									// Scatter gather TX encountered an error
	
	input [31:0] TXN_DATA,							// Read transaction data
	input TXN_LEN_VALID,							// Read transaction length valid
	input TXN_OFF_LAST_VALID,						// Read transaction offset/last valid
	output [31:0] TXN_DONE_LEN,						// Read transaction actual transfer length
	output TXN_DONE,								// Read transaction done
	input TXN_DONE_ACK,								// Read transaction actual transfer length read

	output RX_REQ,									// Read request
	input RX_REQ_ACK,								// Read request accepted
	output [1:0] RX_REQ_TAG,						// Read request data tag 
	output [63:0] RX_REQ_ADDR,						// Read request address
	output [9:0] RX_REQ_LEN,						// Read request length

	input [C_DATA_WIDTH-1:0] MAIN_DATA,				// Main incoming data 
	input [C_DATA_WORD_WIDTH-1:0] MAIN_DATA_EN,		// Main incoming data enable
	input MAIN_DONE,								// Main incoming data complete
	input MAIN_ERR,									// Main incoming data completed with error
	input [C_DATA_WIDTH-1:0] SG_RX_DATA,			// Scatter gather for RX incoming data 
	input [C_DATA_WORD_WIDTH-1:0] SG_RX_DATA_EN,	// Scatter gather for RX incoming data enable
	input SG_RX_DONE,								// Scatter gather for RX incoming data complete
	input SG_RX_ERR,								// Scatter gather for RX incoming data completed with error
	input [C_DATA_WIDTH-1:0] SG_TX_DATA,			// Scatter gather for TX incoming data 
	input [C_DATA_WORD_WIDTH-1:0] SG_TX_DATA_EN,	// Scatter gather for TX incoming data enable
	input SG_TX_DONE,								// Scatter gather for TX incoming data complete
	input SG_TX_ERR,								// Scatter gather for TX incoming data completed with error

	input CHNL_CLK,									// Channel read clock
	output CHNL_RX,									// Channel read receive signal
	input CHNL_RX_ACK,								// Channle read received signal
	output CHNL_RX_LAST,							// Channel last read
	output [31:0] CHNL_RX_LEN,						// Channel read length
	output [30:0] CHNL_RX_OFF,						// Channel read offset
	output [C_DATA_WIDTH-1:0] CHNL_RX_DATA,			// Channel read data
	output CHNL_RX_DATA_VALID,						// Channel read data valid
	input CHNL_RX_DATA_REN							// Channel read data has been recieved
);

`include "common_functions.v"


assign SG_ERR = (wPackedSgTxDone & wPackedSgTxErr);


wire	[C_DATA_WIDTH-1:0]			wPackedMainData;
wire								wPackedMainWen;
wire								wPackedMainDone;
wire								wPackedMainErr;
wire								wMainFlush;
wire								wMainFlushed;

wire	[C_DATA_WIDTH-1:0]			wPackedSgRxData;
wire								wPackedSgRxWen;
wire								wPackedSgRxDone;
wire								wPackedSgRxErr;
wire								wSgRxFlush;
wire								wSgRxFlushed;

wire	[C_DATA_WIDTH-1:0]			wPackedSgTxData;
wire								wPackedSgTxWen;
wire								wPackedSgTxDone;
wire								wPackedSgTxErr;
wire								wSgTxFlush;
wire								wSgTxFlushed;

wire								wMainDataRen;
wire								wMainDataEmpty;
wire	[C_DATA_WIDTH-1:0]			wMainData;

wire								wSgRxRst;
wire								wSgRxDataRen;
wire								wSgRxDataEmpty;
wire	[C_DATA_WIDTH-1:0]			wSgRxData;
wire	[C_SG_FIFO_DEPTH_WIDTH-1:0]	wSgRxFifoCount;

wire								wSgTxRst;
wire	[C_SG_FIFO_DEPTH_WIDTH-1:0]	wSgTxFifoCount;

wire								wSgRxReq;
wire	[63:0]						wSgRxReqAddr;
wire	[9:0]						wSgRxReqLen;

wire								wSgTxReq;
wire	[63:0]						wSgTxReqAddr;
wire	[9:0]						wSgTxReqLen;

wire								wSgRxReqProc;
wire								wSgTxReqProc;
wire								wMainReqProc;
wire								wReqAck;

wire								wSgElemRdy;
wire								wSgElemRen;
wire	[63:0]						wSgElemAddr;
wire	[31:0]						wSgElemLen;

wire								wSgRst;
wire								wMainReq;
wire	[63:0]						wMainReqAddr;
wire	[9:0]						wMainReqLen;
wire								wTxnErr;
wire								wChnlRx;
wire								wChnlRxRecvd;
wire								wChnlRxAckRecvd;
wire								wChnlRxLast;
wire	[31:0]						wChnlRxLen;
wire	[30:0]						wChnlRxOff;
wire	[31:0]						wChnlRxConsumed;

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


// Pack received data tightly into our FIFOs 
fifo_packer_32 mainFifoPacker (
	.CLK(CLK),
	.RST(rRst),
	.DATA_IN(MAIN_DATA),
	.DATA_IN_EN(MAIN_DATA_EN),
	.DATA_IN_DONE(MAIN_DONE),
	.DATA_IN_ERR(MAIN_ERR),
	.DATA_IN_FLUSH(wMainFlush),
	.PACKED_DATA(wPackedMainData),
	.PACKED_WEN(wPackedMainWen),
	.PACKED_DATA_DONE(wPackedMainDone),
	.PACKED_DATA_ERR(wPackedMainErr),
	.PACKED_DATA_FLUSHED(wMainFlushed)
);

fifo_packer_32 sgRxFifoPacker (
	.CLK(CLK),
	.RST(rRst),
	.DATA_IN(SG_RX_DATA),
	.DATA_IN_EN(SG_RX_DATA_EN),
	.DATA_IN_DONE(SG_RX_DONE),
	.DATA_IN_ERR(SG_RX_ERR),
	.DATA_IN_FLUSH(wSgRxFlush),
	.PACKED_DATA(wPackedSgRxData),
	.PACKED_WEN(wPackedSgRxWen),
	.PACKED_DATA_DONE(wPackedSgRxDone),
	.PACKED_DATA_ERR(wPackedSgRxErr),
	.PACKED_DATA_FLUSHED(wSgRxFlushed)
);

fifo_packer_32 sgTxFifoPacker (
	.CLK(CLK),
	.RST(rRst),
	.DATA_IN(SG_TX_DATA),
	.DATA_IN_EN(SG_TX_DATA_EN),
	.DATA_IN_DONE(SG_TX_DONE),
	.DATA_IN_ERR(SG_TX_ERR),
	.DATA_IN_FLUSH(wSgTxFlush),
	.PACKED_DATA(wPackedSgTxData),
	.PACKED_WEN(wPackedSgTxWen),
	.PACKED_DATA_DONE(wPackedSgTxDone),
	.PACKED_DATA_ERR(wPackedSgTxErr),
	.PACKED_DATA_FLUSHED(wSgTxFlushed)
);


// FIFOs for storing received data for the channel.
(* RAM_STYLE="BLOCK" *)
async_fifo_fwft #(.C_WIDTH(C_DATA_WIDTH), .C_DEPTH(C_MAIN_FIFO_DEPTH)) mainFifo (
	.WR_CLK(CLK),
	.WR_RST(rRst | (wTxnErr & TXN_DONE) | wSgRst),
	.WR_EN(wPackedMainWen),
	.WR_DATA(wPackedMainData),
	.WR_FULL(),
	.RD_CLK(CHNL_CLK),
	.RD_RST(rRst | (wTxnErr & TXN_DONE) | wSgRst),
	.RD_EN(wMainDataRen),
	.RD_DATA(wMainData),
	.RD_EMPTY(wMainDataEmpty)
);

(* RAM_STYLE="BLOCK" *)
sync_fifo #(.C_WIDTH(C_DATA_WIDTH), .C_DEPTH(C_SG_FIFO_DEPTH), .C_PROVIDE_COUNT(1)) sgRxFifo (
	.RST(rRst | wSgRxRst),
	.CLK(CLK),
	.WR_EN(wPackedSgRxWen),
	.WR_DATA(wPackedSgRxData),
	.FULL(),
	.RD_EN(wSgRxDataRen),
	.RD_DATA(wSgRxData),
	.EMPTY(wSgRxDataEmpty),
	.COUNT(wSgRxFifoCount)
);

(* RAM_STYLE="BLOCK" *)
sync_fifo #(.C_WIDTH(C_DATA_WIDTH), .C_DEPTH(C_SG_FIFO_DEPTH), .C_PROVIDE_COUNT(1)) sgTxFifo (
	.RST(rRst | wSgTxRst),
	.CLK(CLK),
	.WR_EN(wPackedSgTxWen),
	.WR_DATA(wPackedSgTxData),
	.FULL(),
	.RD_EN(SG_DATA_REN),
	.RD_DATA(SG_DATA),
	.EMPTY(SG_DATA_EMPTY),
	.COUNT(wSgTxFifoCount)
);


// Manage requesting and acknowledging scatter gather data. Note that
// these modules will share the main requestor's RX channel. They will
// take priority over the main logic's use of the RX channel.
sg_list_requester #(.C_FIFO_DATA_WIDTH(C_DATA_WIDTH), .C_FIFO_DEPTH(C_SG_FIFO_DEPTH), .C_MAX_READ_REQ(C_MAX_READ_REQ)) sgRxReq (
	.CLK(CLK),
	.RST(rRst),
	.CONFIG_MAX_READ_REQUEST_SIZE(CONFIG_MAX_READ_REQUEST_SIZE),
	.USER_RST(wSgRst),
	.BUF_RECVD(SG_RX_BUF_RECVD),
	.BUF_DATA(SG_RX_BUF_DATA),
	.BUF_LEN_VALID(SG_RX_BUF_LEN_VALID),
	.BUF_ADDR_HI_VALID(SG_RX_BUF_ADDR_HI_VALID),
	.BUF_ADDR_LO_VALID(SG_RX_BUF_ADDR_LO_VALID),
	.FIFO_COUNT(wSgRxFifoCount),
	.FIFO_FLUSH(wSgRxFlush),
	.FIFO_FLUSHED(wSgRxFlushed),
	.FIFO_RST(wSgRxRst),
	.RX_REQ(wSgRxReq),
	.RX_ADDR(wSgRxReqAddr),
	.RX_LEN(wSgRxReqLen),
	.RX_REQ_ACK(wReqAck & wSgRxReqProc),
	.RX_DONE(wPackedSgRxDone)
);

sg_list_requester #(.C_FIFO_DATA_WIDTH(C_DATA_WIDTH), .C_FIFO_DEPTH(C_SG_FIFO_DEPTH), .C_MAX_READ_REQ(C_MAX_READ_REQ)) sgTxReq (
	.CLK(CLK),
	.RST(rRst),
	.CONFIG_MAX_READ_REQUEST_SIZE(CONFIG_MAX_READ_REQUEST_SIZE),
	.USER_RST(SG_RST),
	.BUF_RECVD(SG_TX_BUF_RECVD),
	.BUF_DATA(SG_TX_BUF_DATA),
	.BUF_LEN_VALID(SG_TX_BUF_LEN_VALID),
	.BUF_ADDR_HI_VALID(SG_TX_BUF_ADDR_HI_VALID),
	.BUF_ADDR_LO_VALID(SG_TX_BUF_ADDR_LO_VALID),
	.FIFO_COUNT(wSgTxFifoCount),
	.FIFO_FLUSH(wSgTxFlush),
	.FIFO_FLUSHED(wSgTxFlushed),
	.FIFO_RST(wSgTxRst),
	.RX_REQ(wSgTxReq),
	.RX_ADDR(wSgTxReqAddr),
	.RX_LEN(wSgTxReqLen),
	.RX_REQ_ACK(wReqAck & wSgTxReqProc),
	.RX_DONE(wPackedSgTxDone)
);


// A read requester for the channel and scatter gather requesters.
rx_port_requester_mux requesterMux (
	.RST(rRst), 
	.CLK(CLK), 
	.SG_RX_REQ(wSgRxReq), 
	.SG_RX_LEN(wSgRxReqLen), 
	.SG_RX_ADDR(wSgRxReqAddr), 
	.SG_RX_REQ_PROC(wSgRxReqProc),
	.SG_TX_REQ(wSgTxReq), 
	.SG_TX_LEN(wSgTxReqLen), 
	.SG_TX_ADDR(wSgTxReqAddr), 
	.SG_TX_REQ_PROC(wSgTxReqProc),
	.MAIN_REQ(wMainReq), 
	.MAIN_LEN(wMainReqLen), 
	.MAIN_ADDR(wMainReqAddr), 
	.MAIN_REQ_PROC(wMainReqProc),
	.RX_REQ(RX_REQ),
	.RX_REQ_ACK(RX_REQ_ACK),
	.RX_REQ_TAG(RX_REQ_TAG),
	.RX_REQ_ADDR(RX_REQ_ADDR),
	.RX_REQ_LEN(RX_REQ_LEN),
	.REQ_ACK(wReqAck)
);


// Read the scatter gather buffer address and length, continuously so that
// we have it ready whenever the next buffer is needed.
sg_list_reader_32 #(.C_DATA_WIDTH(C_DATA_WIDTH)) sgListReader (
	.CLK(CLK),
	.RST(rRst | wSgRst),
	.BUF_DATA(wSgRxData),
	.BUF_DATA_EMPTY(wSgRxDataEmpty),
	.BUF_DATA_REN(wSgRxDataRen),
	.VALID(wSgElemRdy),
	.EMPTY(),
	.REN(wSgElemRen),
	.ADDR(wSgElemAddr),
	.LEN(wSgElemLen)
);


// Main port reader logic
rx_port_reader #(.C_DATA_WIDTH(C_DATA_WIDTH), .C_FIFO_DEPTH(C_MAIN_FIFO_DEPTH), .C_MAX_READ_REQ(C_MAX_READ_REQ)) reader (
	.CLK(CLK), 
	.RST(rRst), 
	.CONFIG_MAX_READ_REQUEST_SIZE(CONFIG_MAX_READ_REQUEST_SIZE),
	.TXN_DATA(TXN_DATA), 
	.TXN_LEN_VALID(TXN_LEN_VALID), 
	.TXN_OFF_LAST_VALID(TXN_OFF_LAST_VALID), 
	.TXN_DONE_LEN(TXN_DONE_LEN),
	.TXN_DONE(TXN_DONE),
	.TXN_ERR(wTxnErr),
	.TXN_DONE_ACK(TXN_DONE_ACK),
	.TXN_DATA_FLUSH(wMainFlush),
	.TXN_DATA_FLUSHED(wMainFlushed),
	.RX_REQ(wMainReq),
	.RX_ADDR(wMainReqAddr),
	.RX_LEN(wMainReqLen),
	.RX_REQ_ACK(wReqAck & wMainReqProc),
	.RX_DATA_EN(MAIN_DATA_EN), 
	.RX_DONE(wPackedMainDone),
	.RX_ERR(wPackedMainErr),
	.SG_DONE(wPackedSgRxDone), 
	.SG_ERR(wPackedSgRxErr), 
	.SG_ELEM_ADDR(wSgElemAddr), 
	.SG_ELEM_LEN(wSgElemLen),
	.SG_ELEM_RDY(wSgElemRdy),
	.SG_ELEM_REN(wSgElemRen),
	.SG_RST(wSgRst),
	.CHNL_RX(wChnlRx), 
	.CHNL_RX_LEN(wChnlRxLen), 
	.CHNL_RX_LAST(wChnlRxLast),
	.CHNL_RX_OFF(wChnlRxOff), 
	.CHNL_RX_RECVD(wChnlRxRecvd), 
	.CHNL_RX_ACK_RECVD(wChnlRxAckRecvd), 
	.CHNL_RX_CONSUMED(wChnlRxConsumed)
);


// Manage the CHNL_RX* signals in the CHNL_CLK domain.
rx_port_channel_gate #(.C_DATA_WIDTH(C_DATA_WIDTH)) gate (
	.RST(rRst), 
	.CLK(CLK), 
	.RX(wChnlRx), 
	.RX_RECVD(wChnlRxRecvd), 
	.RX_ACK_RECVD(wChnlRxAckRecvd), 
	.RX_LAST(wChnlRxLast), 
	.RX_LEN(wChnlRxLen), 
	.RX_OFF(wChnlRxOff), 
	.RX_CONSUMED(wChnlRxConsumed), 
	.RD_DATA(wMainData), 
	.RD_EMPTY(wMainDataEmpty), 
	.RD_EN(wMainDataRen), 
	.CHNL_CLK(CHNL_CLK), 
	.CHNL_RX(CHNL_RX), 
	.CHNL_RX_ACK(CHNL_RX_ACK), 
	.CHNL_RX_LAST(CHNL_RX_LAST), 
	.CHNL_RX_LEN(CHNL_RX_LEN), 
	.CHNL_RX_OFF(CHNL_RX_OFF), 
	.CHNL_RX_DATA(CHNL_RX_DATA), 
	.CHNL_RX_DATA_VALID(CHNL_RX_DATA_VALID), 
	.CHNL_RX_DATA_REN(CHNL_RX_DATA_REN)
);


endmodule
