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
// Filename:			tx_engine_lower_128.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Transmit engine for completion requests and pre-formatted
// PCIe read/write data. Muxes traffic for the AXI interface on the Xilinx PCIe 
// Endpoint core.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
// Additional Comments: Very good PCIe header reference:
// http://www.pzk-agro.com/0321156307_ch04lev1sec5.html#ch04lev4sec14
// Also byte swap each payload word due to Xilinx incorrect mapping, see
// http://forums.xilinx.com/t5/PCI-Express/PCI-Express-payload-required-to-be-Big-Endian-by-specification/td-p/285551
//-----------------------------------------------------------------------------
`define FMT_TXENGLWR128_CPLD	7'b10_01010

`define S_TXENGLWR128_IDLE		2'd0
`define S_TXENGLWR128_CPLD_0	2'd1
`define S_TXENGLWR128_CPLD_1	2'd2
`define S_TXENGLWR128_WR		2'd3

module tx_engine_lower_128 #(
	parameter C_PCI_DATA_WIDTH = 9'd128,
	parameter C_NUM_CHNL = 4'd12,
	parameter C_ALTERA = 1'b1
)
(
	input CLK,
	input RST,

	input [15:0] CONFIG_COMPLETER_ID,

	output [C_PCI_DATA_WIDTH-1:0] TX_DATA,					// AXI data output 
	output [(C_PCI_DATA_WIDTH/8)-1:0] TX_DATA_BYTE_ENABLE,	// AXI data keep
	output TX_TLP_END_FLAG,									// AXI data last
	output TX_DATA_VALID,									// AXI data valid
	output S_AXIS_SRC_DSC,									// AXI data discontinue
    output TX_TLP_START_FLAG,								// AXI data start
	input TX_DATA_READY,									// AXI ready for data

	input COMPL_REQ,										// RX Engine request for completion
	output COMPL_DONE,										// Completion done
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
	output [31:0] REQ_DATA_SENT,							// Actual completion data sent

	input [C_PCI_DATA_WIDTH-1:0] FIFO_DATA,					// Read/Write FIFO requests + data
	input FIFO_EMPTY,										// Read/Write FIFO is empty
	output FIFO_REN,										// Read/Write FIFO read enable
	output [C_NUM_CHNL-1:0] WR_SENT 						// Pulsed at channel pos when write request sent
    );


reg [11:0]                         rByteCount=0;
reg [6:0]                          rLowerAddr=0;

reg                                rFifoRen=0, _rFifoRen=0;
reg                                rFifoRenIssued=0, _rFifoRenIssued=0;
reg                                rFifoDataEmpty=1, _rFifoDataEmpty=1;
reg [2:0]                          rFifoDataValid=0, _rFifoDataValid=0;
reg [(3*C_PCI_DATA_WIDTH)-1:0]     rFifoData={3*C_PCI_DATA_WIDTH{1'd0}}, _rFifoData={3*C_PCI_DATA_WIDTH{1'd0}};
wire [(3*C_PCI_DATA_WIDTH)-1:0]    wFifoData = (rFifoData>>(C_PCI_DATA_WIDTH*(!rFifoRen)))>>(C_PCI_DATA_WIDTH*(!rFifoRenIssued));
wire [2:0]                         wFifoDataValid = (rFifoDataValid>>(!rFifoRen))>>(!rFifoRenIssued);

reg [1:0]                          rState=`S_TXENGLWR128_IDLE, _rState=`S_TXENGLWR128_IDLE;
reg                                rComplDone=0, _rComplDone=0;
reg                                rValid=0, _rValid=0;
reg [C_PCI_DATA_WIDTH-1:0]         rData={C_PCI_DATA_WIDTH{1'd0}}, _rData={C_PCI_DATA_WIDTH{1'd0}};
reg                                rLast=0, _rLast=0;
reg                                rFirst=0, _rFirst=0;
reg [3:0]                          rKeep=0, _rKeep=0;
reg [C_NUM_CHNL-1:0]               rDone=0, _rDone=0;
reg [9:0]                          rLen=0, _rLen=0;
reg                                rIsLast=0, _rIsLast=0;
wire [31:0]                        wReqDataSwap;
wire [7:0]                         wKeep = (8'b00001111<<(rLen[2:0])) | {8{!rIsLast}};			


assign TX_DATA = rData;
assign TX_DATA_BYTE_ENABLE = {{4{rKeep[3]}}, {4{rKeep[2]}}, {4{rKeep[1]}}, {4{rKeep[0]}}};
assign TX_TLP_END_FLAG = rLast;
assign TX_TLP_START_FLAG = rFirst;
assign TX_DATA_VALID = rValid;
assign S_AXIS_SRC_DSC = 0;

assign COMPL_DONE = rComplDone;

generate
if(C_ALTERA == 1'b1) begin : altera_data
	assign REQ_DATA_SENT = rData[127:96];
	assign wReqDataSwap = REQ_DATA[31:0];
end 
else begin : xilinx_data
	assign REQ_DATA_SENT = {rData[103:96], rData[111:104], rData[119:112], rData[127:120]};
	assign wReqDataSwap = {REQ_DATA[7:0], REQ_DATA[15:8], REQ_DATA[23:16], REQ_DATA[31:24]};
end
endgenerate
   

assign FIFO_REN = rFifoRen;
assign WR_SENT = rDone;


// Calculate byte count based on byte enable
always @ (REQ_BE) begin
	casex (REQ_BE)
	4'b1xx1 : rByteCount = 12'h004;
	4'b01x1 : rByteCount = 12'h003;
	4'b1x10 : rByteCount = 12'h003;
	4'b0011 : rByteCount = 12'h002;
	4'b0110 : rByteCount = 12'h002;
	4'b1100 : rByteCount = 12'h002;
	4'b0001 : rByteCount = 12'h001;
	4'b0010 : rByteCount = 12'h001;
	4'b0100 : rByteCount = 12'h001;
	4'b1000 : rByteCount = 12'h001;
	4'b0000 : rByteCount = 12'h001;
	endcase
end


// Calculate lower address based on byte enable
always @ (REQ_BE or REQ_ADDR) begin
	casex (REQ_BE)
	4'b0000 : rLowerAddr = {REQ_ADDR[4:0], 2'b00};
	4'bxxx1 : rLowerAddr = {REQ_ADDR[4:0], 2'b00};
	4'bxx10 : rLowerAddr = {REQ_ADDR[4:0], 2'b01};
	4'bx100 : rLowerAddr = {REQ_ADDR[4:0], 2'b10};
	4'b1000 : rLowerAddr = {REQ_ADDR[4:0], 2'b11};
	endcase
end


// Read in the pre-formatted PCIe data.
always @ (posedge CLK) begin
	rFifoRenIssued <= #1 (RST ? 1'd0 : _rFifoRenIssued);
	rFifoDataValid <= #1 (RST ? 1'd0 : _rFifoDataValid);
	rFifoDataEmpty <= #1 (RST ? 1'd1 : _rFifoDataEmpty);
	rFifoData <= #1 _rFifoData;
end

always @ (*) begin
	_rFifoRenIssued = rFifoRen;
	_rFifoDataEmpty = (rFifoRen ? FIFO_EMPTY : rFifoDataEmpty);

	if (rFifoRenIssued) begin
		_rFifoData = ((rFifoData<<(C_PCI_DATA_WIDTH)) | FIFO_DATA);
		_rFifoDataValid = ((rFifoDataValid<<1) | (!rFifoDataEmpty));
	end
	else begin
		_rFifoData = rFifoData;
		_rFifoDataValid = rFifoDataValid;
	end
end


// Multiplex completion requests and read/write pre-formatted PCIe data onto
// the AXI PCIe Endpoint interface. Remember that TX_DATA_READY may drop at
// *any* time during transmission. So be sure to buffer enough data to 
// accommodate starts and stops.
always @ (posedge CLK) begin
	rState <= #1 (RST ? `S_TXENGLWR128_IDLE : _rState);
	rComplDone <= #1 (RST ? 1'd0 : _rComplDone);
	rValid <= #1 (RST ? 1'd0 : _rValid);
	rFifoRen <= #1 (RST ? 1'd0 : _rFifoRen);
	rDone <= #1 (RST ? {C_NUM_CHNL{1'd0}} : _rDone);
	rData <= #1 _rData;
	rLast <= #1 _rLast;
	rKeep <= #1 _rKeep;
	rLen <= #1 _rLen;
	rIsLast <= #1 _rIsLast;
	rFirst <= #1 _rFirst;
end

always @ (*) begin
	_rState = rState;
	_rComplDone = rComplDone;
	_rValid = rValid;
	_rFifoRen = rFifoRen;
	_rData = rData;
	_rLast = rLast;
	_rKeep = rKeep;
	_rDone = rDone;
	_rLen = rLen;
	_rIsLast = rIsLast;
	_rFirst = rFirst;
  
	case (rState) 

	`S_TXENGLWR128_IDLE : begin
		_rFifoRen = (TX_DATA_READY & !COMPL_REQ);
		_rDone = ((TX_DATA_READY & !COMPL_REQ & wFifoDataValid[0] & wFifoData[30])<<wFifoData[19:16]); // CHNL buried in header
		if (TX_DATA_READY) begin // Check for throttling
			_rData = {wFifoData[127:20], 4'd0, wFifoData[15:0]}; // Revert the reserved 4 bits back to 0.
			_rValid = (!COMPL_REQ & wFifoDataValid[0]);
			_rFirst = 1;
			_rLast = (!wFifoData[30] | (!wFifoData[29] & !wFifoData[36])); // Not WRITE TLP or (!64 bit & !(LEN != 1))
			_rKeep = (4'b1111>>(!wFifoData[30] & !wFifoData[29])); // Not WRITE TLP && !64 bit 
			_rLen = wFifoData[9:0] - !wFifoData[29]; // LEN - !64 bit
			_rIsLast = (wFifoData[9:0] <= {1'b1, 1'b0, !wFifoData[29]}); // LEN <= 4 + !64 bit
			if (COMPL_REQ) // PIO read completions
				_rState = `S_TXENGLWR128_CPLD_0;
			else if (wFifoDataValid[0]) // Read FIFO data if it's ready
				_rState = (wFifoData[30] & (wFifoData[29] | wFifoData[36]) ? `S_TXENGLWR128_WR : `S_TXENGLWR128_IDLE); // WRITE TLP & (64 bit | LEN != 1)?
		end
	end

	`S_TXENGLWR128_CPLD_0 : begin
		if (TX_DATA_READY) begin // Check for throttling
			_rComplDone = 1;
			_rValid = 1;
			_rLast = 1;
			_rFirst = 1;
			_rKeep = 4'b1111;
			_rData = {wReqDataSwap,														// DW3
						REQ_ID, REQ_TAG, 1'b0, rLowerAddr,								// DW2
						CONFIG_COMPLETER_ID[15:3], 3'b0, 3'b0, 1'b0, rByteCount,		// DW1
						1'b0, `FMT_TXENGLWR128_CPLD, 1'b0, REQ_TC, 4'b0, REQ_TD,
						REQ_EP, REQ_ATTR, 2'b0, REQ_LEN};								// DW0
			_rState = `S_TXENGLWR128_CPLD_1;
		end
	end

	`S_TXENGLWR128_CPLD_1 : begin
		// Just wait a cycle for the COMP_REQ to drop.
		_rComplDone = 0;
		if (TX_DATA_READY) begin // Check for throttling
			_rFirst = 0;
			_rValid = 0;
			_rState = `S_TXENGLWR128_IDLE;
		end
	end

	`S_TXENGLWR128_WR : begin
		_rFifoRen = TX_DATA_READY;
		_rDone = 0;
		if (TX_DATA_READY) begin // Check for throttling
			_rFirst = 0;
			_rData = wFifoData[127:0];
			_rValid = 1;
			_rLast = rIsLast;
			_rKeep = wKeep[7:4];			
			_rLen = rLen - 3'd4;
			_rIsLast = (rLen <= 4'd8);
			_rState = (rIsLast ? `S_TXENGLWR128_IDLE : `S_TXENGLWR128_WR);
		end
	end

	endcase
end


endmodule
