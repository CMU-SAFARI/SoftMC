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
// Filename:			interrupt_controller.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Signals an interrupt on the Xilnx PCIe Endpoint 
// 						interface. Supports single vector MSI or legacy based
// 						interrupts. 
//						When INTR is pulsed high, the interrupt will be issued
//						as soon as possible. If using legacy interrupts, the 
//						initial interrupt must be cleared by another request
//						(typically a PIO read or write request to the 
//						endpoint at some predetermined BAR address). Receipt of
//						the "clear" acknowledgment should cause INTR_LEGACY_CLR 
// 						input to pulse high. Thus completing the legacy 
//						interrupt cycle. If using MSI interrupts, no such
//						acknowldegment is necessary.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------
`define S_INTRCTLR_IDLE				3'd0
`define S_INTRCLTR_WORKING			3'd1
`define S_INTRCLTR_COMPLETE			3'd2
`define S_INTRCLTR_CLEAR_LEGACY		3'd3
`define S_INTRCLTR_CLEARING_LEGACY	3'd4
`define S_INTRCLTR_DONE				3'd5

module interrupt_controller (
	input CLK,						// System clock
	input RST,						// Async reset
	input INTR,						// Pulsed high to request an interrupt
	input INTR_LEGACY_CLR,			// Pulsed high to ack the legacy interrupt and clear it
	output INTR_DONE,				// Pulsed high to signal interrupt sent
	input CONFIG_INTERRUPT_MSIENABLE,	// 1 if MSI interrupts are enable, 0 if only legacy are supported
	output CFG_INTERRUPT_ASSERT,	// Legacy interrupt message type
	input INTR_MSI_RDY,		// High when interrupt is able to be sent
	output INTR_MSI_REQUEST			// High to request interrupt, when both INTR_MSI_RDY and INTR_MSI_REQUEST are high, interrupt is sent
);

reg		[2:0]	rState=`S_INTRCTLR_IDLE;
reg		[2:0]	rStateNext=`S_INTRCTLR_IDLE;
reg				rIntr=0;
reg				rIntrAssert=0;

assign INTR_DONE = (rState == `S_INTRCLTR_DONE);
assign INTR_MSI_REQUEST = rIntr;
assign CFG_INTERRUPT_ASSERT = rIntrAssert;

// Control sending interrupts.
always @(*) begin
	case (rState)

	`S_INTRCTLR_IDLE : begin
		if (INTR) begin
			rIntr = 1;
			rIntrAssert = !CONFIG_INTERRUPT_MSIENABLE;
			rStateNext = (INTR_MSI_RDY ? `S_INTRCLTR_COMPLETE : `S_INTRCLTR_WORKING);
		end 
		else begin
			rIntr = 0;
			rIntrAssert = 0;
			rStateNext = `S_INTRCTLR_IDLE;
		end
	end

	`S_INTRCLTR_WORKING : begin
		rIntr = 1;
		rIntrAssert = !CONFIG_INTERRUPT_MSIENABLE;
		rStateNext = (INTR_MSI_RDY ? `S_INTRCLTR_COMPLETE : `S_INTRCLTR_WORKING);
	end

	`S_INTRCLTR_COMPLETE : begin
		rIntr = 0;
		rIntrAssert = !CONFIG_INTERRUPT_MSIENABLE;
		rStateNext = (CONFIG_INTERRUPT_MSIENABLE ? `S_INTRCLTR_DONE : `S_INTRCLTR_CLEAR_LEGACY);
	end

	`S_INTRCLTR_CLEAR_LEGACY : begin
		if (INTR_LEGACY_CLR) begin
			rIntr = 1;
			rIntrAssert = 0;
			rStateNext = (INTR_MSI_RDY ? `S_INTRCLTR_DONE : `S_INTRCLTR_CLEARING_LEGACY);
		end 
		else begin
			rIntr = 0;
			rIntrAssert = 1;
			rStateNext = `S_INTRCLTR_CLEAR_LEGACY;
		end
	end

	`S_INTRCLTR_CLEARING_LEGACY : begin
		rIntr = 1;
		rIntrAssert = 0;
		rStateNext = (INTR_MSI_RDY ? `S_INTRCLTR_DONE : `S_INTRCLTR_CLEARING_LEGACY);
	end

	`S_INTRCLTR_DONE : begin
		rIntr = 0;
		rIntrAssert = 0;
		rStateNext = `S_INTRCTLR_IDLE;
	end
	
	default: begin
		rIntr = 0;
		rIntrAssert = 0;
		rStateNext = `S_INTRCTLR_IDLE;
	end
	
	endcase
end

// Update the state.
always @(posedge CLK) begin
	if (RST)
		rState <= #1 `S_INTRCTLR_IDLE;
	else
		rState <= #1 rStateNext;
end

endmodule

