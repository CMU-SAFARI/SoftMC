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
// Filename:			tx_engine_selector.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Searches for read and write requests.
//						PCIe Endpoint core.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
// Additional Comments: 
//-----------------------------------------------------------------------------

module tx_engine_selector #(
	parameter C_NUM_CHNL = 4'd12
)
(
	input CLK,
	input RST,

	input [C_NUM_CHNL-1:0] REQ_ALL,	// Write requests

	output REQ,						// Write request
	output [3:0] CHNL				// Write channel
);

reg		[3:0]						rReqChnl=0, _rReqChnl=0;
reg		[3:0]						rReqChnlNext=0, _rReqChnlNext=0;
reg									rReqChnlsSame=0, _rReqChnlsSame=0;
reg		[3:0]						rChnlNext=0, _rChnlNext=0;
reg		[3:0]						rChnlNextNext=0, _rChnlNextNext=0;
reg									rChnlNextDfrnt=0, _rChnlNextDfrnt=0;
reg									rChnlNextNextOn=0, _rChnlNextNextOn=0;
wire								wChnlNextNextOn = (REQ_ALL>>(rChnlNextNext));
reg									rReq=0, _rReq=0;
wire								wReq = (REQ_ALL>>(rReqChnl));
reg									rReqChnlNextUpdated=0, _rReqChnlNextUpdated=0;


assign REQ = rReq;
assign CHNL = rReqChnl;


// Search for the next request so that we can move onto it immediately after
// the current channel has released its request.
always @ (posedge CLK) begin
	rReq <= #1 (RST ? 1'd0 : _rReq);
	rReqChnl <= #1 (RST ? 4'd0 : _rReqChnl);
	rReqChnlNext <= #1 (RST ? 4'd0 : _rReqChnlNext);
	rChnlNext <= #1 (RST ? 4'd0 : _rChnlNext);
	rChnlNextNext <= #1 (RST ? 4'd0 : _rChnlNextNext);
	rChnlNextDfrnt <= #1 (RST ? 1'd0 : _rChnlNextDfrnt);
	rChnlNextNextOn <= #1 (RST ? 1'd0 : _rChnlNextNextOn);
	rReqChnlsSame <= #1 (RST ? 1'd0 : _rReqChnlsSame);
	rReqChnlNextUpdated <= #1 (RST ? 1'd1 : _rReqChnlNextUpdated);
end

always @ (*) begin
	// Go through each channel (RR), looking for requests
	_rChnlNextNextOn = wChnlNextNextOn;
	_rChnlNext = rChnlNextNext;
	_rChnlNextNext = (rChnlNextNext == C_NUM_CHNL - 1 ? 4'd0 : rChnlNextNext + 1'd1);
	_rChnlNextDfrnt = (rChnlNextNext != rReqChnl);
	_rReqChnlsSame = (rReqChnlNext == rReqChnl);

	// Save ready channel if it is not the same channel we're currently on
	if (rChnlNextNextOn & rChnlNextDfrnt & rReqChnlsSame & !rReqChnlNextUpdated) begin
		_rReqChnlNextUpdated = 1;
		_rReqChnlNext = rChnlNext;
	end
	else begin
		_rReqChnlNextUpdated = 0;
		_rReqChnlNext = rReqChnlNext;
	end
	
	// Assign the new channel
	_rReq = wReq;
	_rReqChnl = (!rReq ? rReqChnlNext : rReqChnl);
end


endmodule
