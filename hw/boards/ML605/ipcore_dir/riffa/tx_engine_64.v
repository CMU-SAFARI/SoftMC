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
// Filename:			tx_engine_64.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Transmit engine for PCIe using AXI interface from Xilinx 
// PCIe Endpoint core.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
// Additional Comments: Very good PCIe header reference:
// http://www.pzk-agro.com/0321156307_ch04lev1sec5.html#ch04lev4sec14
//-----------------------------------------------------------------------------

module tx_engine_64 #(
	parameter C_PCI_DATA_WIDTH = 9'd64,
	parameter C_NUM_CHNL = 4'd12,
	parameter C_TAG_WIDTH = 5, 							// Number of outstanding requests 
	parameter C_ALTERA = 1'b1,							// 1 if Altera, 0 if Xilinx
	// Local parameters
	parameter C_FIFO_DEPTH = 512,
	parameter C_FIFO_DEPTH_WIDTH = clog2((2**clog2(C_FIFO_DEPTH))+1)
)
(
	input CLK,
	input RST,
	input [15:0] CONFIG_COMPLETER_ID,
	input [2:0] CONFIG_MAX_PAYLOAD_SIZE,				// Maximum write payload: 000=128B, 001=256B, 010=512B, 011=1024B

	output [C_PCI_DATA_WIDTH-1:0] TX_DATA,				// AXI data output 
	output [(C_PCI_DATA_WIDTH/8)-1:0] TX_DATA_BYTE_ENABLE,	// AXI data keep
	output TX_TLP_END_FLAG,								// AXI data last
    output TX_TLP_START_FLAG,                           // AXI data first
	output TX_DATA_VALID,								// AXI data valid
	output S_AXIS_SRC_DSC,								// AXI data discontinue
	input TX_DATA_READY,								// AXI ready for data

	input [C_NUM_CHNL-1:0] WR_REQ,						// Write request
	input [(C_NUM_CHNL*64)-1:0] WR_ADDR,				// Write address
	input [(C_NUM_CHNL*10)-1:0] WR_LEN,					// Write data length
	input [(C_NUM_CHNL*C_PCI_DATA_WIDTH)-1:0] WR_DATA,	// Write data
	output [C_NUM_CHNL-1:0] WR_DATA_REN,				// Write data read enable
	output [C_NUM_CHNL-1:0] WR_ACK,						// Write request has been accepted
	output [C_NUM_CHNL-1:0] WR_SENT, 					// Pulsed at channel pos when write request sent

	input [C_NUM_CHNL-1:0] RD_REQ,						// Read request
	input [(C_NUM_CHNL*2)-1:0] RD_SG_CHNL,				// Read request channel for scatter gather lists
	input [(C_NUM_CHNL*64)-1:0] RD_ADDR,				// Read request address
	input [(C_NUM_CHNL*10)-1:0] RD_LEN,					// Read request length
	output [C_NUM_CHNL-1:0] RD_ACK,						// Read request has been accepted
	
	output [5:0] INT_TAG,								// Internal tag to exchange with external
	output INT_TAG_VALID,								// High to signal tag exchange 
	input [C_TAG_WIDTH-1:0] EXT_TAG,					// External tag to provide in exchange for internal tag
	input EXT_TAG_VALID,								// High to signal external tag is valid

    output 				      TX_ENG_RD_REQ_SENT, // Read completion request issued
    input 				      RXBUF_SPACE_AVAIL,
	
	input COMPL_REQ,									// RX Engine request for completion
	output COMPL_DONE,									// Completion done
	input [2:0] REQ_TC,
	input REQ_TD,
	input REQ_EP,
	input [1:0] REQ_ATTR,
	input [9:0] REQ_LEN,
	input [15:0] REQ_ID,
	input [7:0] REQ_TAG,
	input [3:0] REQ_BE,
	input [29:0] REQ_ADDR,
	input [31:0] REQ_DATA,
	output [31:0] REQ_DATA_SENT							// Actual completion data sent
);

`include "common_functions.v"

wire 	[C_PCI_DATA_WIDTH-1:0]		wFifoWrData;
wire 	[C_PCI_DATA_WIDTH-1:0]		wFifoRdData;
wire	[C_FIFO_DEPTH_WIDTH-1:0]	wFifoCount;
wire								wFifoEmpty;
wire								wFifoRen;
wire								wFifoWen;
wire								wAltera = C_ALTERA;

// Convert the read and write requests into PCI packet format and mux
// them together into a FIFO.
tx_engine_upper_64 #(
    .C_PCI_DATA_WIDTH(C_PCI_DATA_WIDTH), 
    .C_NUM_CHNL(C_NUM_CHNL), 
	.C_FIFO_DEPTH(C_FIFO_DEPTH), 
    .C_TAG_WIDTH(C_TAG_WIDTH),
	.C_ALTERA(C_ALTERA)
) upper (
	.RST(RST),
	.CLK(CLK),
	.CONFIG_COMPLETER_ID(CONFIG_COMPLETER_ID),
	.CONFIG_MAX_PAYLOAD_SIZE(CONFIG_MAX_PAYLOAD_SIZE),
	.WR_REQ(WR_REQ),
	.WR_ADDR(WR_ADDR),
	.WR_LEN(WR_LEN),
	.WR_DATA(WR_DATA),
	.WR_DATA_REN(WR_DATA_REN),
	.WR_ACK(WR_ACK),
	.RD_REQ(RD_REQ),
	.RD_SG_CHNL(RD_SG_CHNL),
	.RD_ADDR(RD_ADDR),
	.RD_LEN(RD_LEN),
	.RD_ACK(RD_ACK),
    .TX_ENG_RD_REQ_SENT(TX_ENG_RD_REQ_SENT),
    .RXBUF_SPACE_AVAIL(RXBUF_SPACE_AVAIL | !wAltera),
	.INT_TAG(INT_TAG),
	.INT_TAG_VALID(INT_TAG_VALID),
	.EXT_TAG(EXT_TAG),
	.EXT_TAG_VALID(EXT_TAG_VALID),
	.FIFO_DATA(wFifoWrData),
	.FIFO_COUNT(wFifoCount),
	.FIFO_WEN(wFifoWen)
);


// FIFO for storing outbound read/write requests.
(* RAM_STYLE="BLOCK" *)
sync_fifo #(.C_WIDTH(C_PCI_DATA_WIDTH), .C_DEPTH(C_FIFO_DEPTH), .C_PROVIDE_COUNT(1)) fifo (
	.RST(RST),
	.CLK(CLK),
	.WR_EN(wFifoWen),
	.WR_DATA(wFifoWrData),
	.FULL(),
	.COUNT(wFifoCount),
	.RD_EN(wFifoRen),
	.RD_DATA(wFifoRdData),
	.EMPTY(wFifoEmpty)
);


// Process the formatted PCI packets in the FIFO and completions.
// Completions take top priority. Mux the data into the AXI interface
// for the PCIe Endpoint.
tx_engine_lower_64 #(
	.C_PCI_DATA_WIDTH(C_PCI_DATA_WIDTH), 
	.C_NUM_CHNL(C_NUM_CHNL),
	.C_ALTERA(C_ALTERA)
) lower (
	.RST(RST),
	.CLK(CLK),
	.CONFIG_COMPLETER_ID(CONFIG_COMPLETER_ID),
	.TX_DATA(TX_DATA),
	.TX_DATA_BYTE_ENABLE(TX_DATA_BYTE_ENABLE),
	.TX_TLP_END_FLAG(TX_TLP_END_FLAG),
    .TX_TLP_START_FLAG(TX_TLP_START_FLAG),
	.TX_DATA_VALID(TX_DATA_VALID),
	.S_AXIS_SRC_DSC(S_AXIS_SRC_DSC),
	.TX_DATA_READY(TX_DATA_READY),
	.COMPL_REQ(COMPL_REQ),
	.COMPL_DONE(COMPL_DONE),
	.REQ_TC(REQ_TC),
	.REQ_TD(REQ_TD),
	.REQ_EP(REQ_EP),
	.REQ_ATTR(REQ_ATTR),
	.REQ_LEN(REQ_LEN),
	.REQ_ID(REQ_ID),
	.REQ_TAG(REQ_TAG),
	.REQ_BE(REQ_BE),
	.REQ_ADDR(REQ_ADDR),
	.REQ_DATA(REQ_DATA),
	.REQ_DATA_SENT(REQ_DATA_SENT),
	.FIFO_DATA(wFifoRdData),
	.FIFO_EMPTY(wFifoEmpty),
	.FIFO_REN(wFifoRen),
	.WR_SENT(WR_SENT)
);


endmodule
