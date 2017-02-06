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
// Filename:			recv_credit_flow_ctrl.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:		Monitors the receive completion credits for headers and
// 			data to make sure the rx_port modules don't request too 
//			much data from the root complex, as this could result in
//			some data being dropped/lost.
// Author:		Matt Jacobsen
// Author:		Dustin Richmond
// History:		@mattj: Version 2.0
//-----------------------------------------------------------------------------
module recv_credit_flow_ctrl
  (
   input 	CLK,
   input 	RST,
   input [2:0] 	CONFIG_MAX_READ_REQUEST_SIZE, // Maximum read payload: 000=128B, 001=256B, 010=512B, 011=1024B, 100=2048B, 101=4096B
   input [11:0] CONFIG_MAX_CPL_DATA, // Receive credit limit for data
   input [7:0] 	CONFIG_MAX_CPL_HDR, // Receive credit limit for headers
   input 	CONFIG_CPL_BOUNDARY_SEL, // Read completion boundary (0=64 bytes, 1=128 bytes)w
   input 	RX_ENG_RD_DONE, // Read completed
   input 	TX_ENG_RD_REQ_SENT, // Read completion request issued
   output 	RXBUF_SPACE_AVAIL // High if enough read completion credits exist to make a read completion request
   );

   reg 		rCreditAvail=0;
   reg 		rCplDAvail=0;
   reg 		rCplHAvail=0;
   reg [12:0] 	rMaxRecv=0;
   reg [11:0] 	rCplDAmt=0;
   reg [7:0] 	rCplHAmt=0;
   reg [11:0] 	rCplD=0;
   reg [7:0] 	rCplH=0;

   assign RXBUF_SPACE_AVAIL = rCreditAvail;

   // Determine the completions required for a max read completion request.
   always @(posedge CLK) begin
      rMaxRecv <= #1 (13'd128<<CONFIG_MAX_READ_REQUEST_SIZE);
      rCplHAmt <= #1 (rMaxRecv>>({2'b11, CONFIG_CPL_BOUNDARY_SEL}));
      rCplDAmt <= #1 (rMaxRecv>>4);
      rCplHAvail <= #1 (rCplH <= CONFIG_MAX_CPL_HDR);
      rCplDAvail <= #1 (rCplD <= CONFIG_MAX_CPL_DATA);
      rCreditAvail <= #1 (rCplHAvail & rCplDAvail);
   end

   // Count the number of outstanding read completion requests.
   always @ (posedge CLK) begin
      if (RST) begin
	 rCplH <= #1 0;
	 rCplD <= #1 0;
      end
      else if (RX_ENG_RD_DONE & TX_ENG_RD_REQ_SENT) begin
	 rCplH <= #1 rCplH;
	 rCplD <= #1 rCplD;
      end
      else if (TX_ENG_RD_REQ_SENT) begin
	 rCplH <= #1 rCplH + rCplHAmt;
	 rCplD <= #1 rCplD + rCplDAmt;
      end
      else if (RX_ENG_RD_DONE) begin
	 rCplH <= #1 rCplH - rCplHAmt;
	 rCplD <= #1 rCplD - rCplDAmt;
      end
   end

endmodule
