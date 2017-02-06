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
// Filename:			ram_2clk_1w_1r.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			An inferrable RAM module. Dual clocks, 1 write port, 1 
//						read port. In Xilinx designs, specify RAM_STYLE="BLOCK" 
//						to use BRAM memory or RAM_STYLE="DISTRIBUTED" to use 
//						LUT memory.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------
module ram_2clk_1w_1r (
	CLKA,
	ADDRA,
	WEA,
	DINA,
	CLKB,
	ADDRB,
	DOUTB
);

`include "common_functions.v"

parameter C_RAM_WIDTH = 32;
parameter C_RAM_DEPTH = 1024;
//Local parameters
parameter C_RAM_ADDR_BITS = clog2s(C_RAM_DEPTH);

input							CLKA;
input							CLKB;
input 							WEA;
input 	[C_RAM_ADDR_BITS-1:0]	ADDRA;
input 	[C_RAM_ADDR_BITS-1:0]	ADDRB;
input 	[C_RAM_WIDTH-1:0]		DINA;
output 	[C_RAM_WIDTH-1:0]		DOUTB;

reg [C_RAM_WIDTH-1:0] rRAM [C_RAM_DEPTH-1:0];
reg [C_RAM_WIDTH-1:0] rDout;   

assign DOUTB = rDout;

always @(posedge CLKA) begin
  if (WEA)
	 rRAM[ADDRA] <= #1 DINA;
end

always @(posedge CLKB) begin
  rDout <= #1 rRAM[ADDRB];
end
						
endmodule
