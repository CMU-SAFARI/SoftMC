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
// Filename:			riffa_endpoint.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Generates the appropriate riffa_endpoint based on the 
// 						data width.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------
module riffa_endpoint #(
	parameter C_PCI_DATA_WIDTH = 9'd64,
	parameter C_NUM_CHNL = 4'd12,
	parameter C_MAX_READ_REQ_BYTES = 512,	// Max size of read requests (in bytes)
	parameter C_TAG_WIDTH = 5, 				// Number of outstanding requests 
	parameter C_ALTERA = 1'b1				// 1 if Altera, 0 if Xilinx
)
(
	input CLK,
	input RST_IN,
	output RST_OUT,

	input [C_PCI_DATA_WIDTH-1:0] M_AXIS_RX_TDATA,
	input [(C_PCI_DATA_WIDTH/8)-1:0] M_AXIS_RX_TKEEP,
	input M_AXIS_RX_TLAST,
	input M_AXIS_RX_TVALID,
	output M_AXIS_RX_TREADY,
	input [4:0] IS_SOF,
	input [4:0] IS_EOF,
	input RERR_FWD,
	
	output [C_PCI_DATA_WIDTH-1:0] S_AXIS_TX_TDATA,
	output [(C_PCI_DATA_WIDTH/8)-1:0] S_AXIS_TX_TKEEP,
	output S_AXIS_TX_TLAST,
	output S_AXIS_TX_TVALID,
	output S_AXIS_SRC_DSC,
	input S_AXIS_TX_TREADY,
	
	input [15:0] COMPLETER_ID,
	input CFG_BUS_MSTR_ENABLE,	
	input [5:0] CFG_LINK_WIDTH,			// cfg_lstatus[9:4] (from Link Status Register): 000001=x1, 000010=x2, 000100=x4, 001000=x8, 001100=x12, 010000=x16, 100000=x32, others=? 
	input [1:0] CFG_LINK_RATE,			// cfg_lstatus[1:0] (from Link Status Register): 01=2.5GT/s, 10=5.0GT/s, others=?
	input [2:0] MAX_READ_REQUEST_SIZE,	// cfg_dcommand[14:12] (from Device Control Register): 000=128B, 001=256B, 010=512B, 011=1024B, 100=2048B, 101=4096B
	input [2:0] MAX_PAYLOAD_SIZE, 		// cfg_dcommand[7:5] (from Device Control Register): 000=128B, 001=256B, 010=512B, 011=1024B
	input CFG_INTERRUPT_MSIEN,			// 1 if MSI interrupts are enable, 0 if only legacy are supported
	input CFG_INTERRUPT_RDY,			// High when interrupt is able to be sent
	output CFG_INTERRUPT,				// High to request interrupt, when both CFG_INTERRUPT_RDY and CFG_INTERRUPT are high, interrupt is sent
    input 				       RCB,
    input [11:0] 			       MAX_RC_CPLD, // Receive credit limit for data (be sure fc_sel == 001)
    input [7:0] 			       MAX_RC_CPLH, // Receive credit limit for headers (be sure fc_sel == 001)
	
    // Altera Signals
    input [C_PCI_DATA_WIDTH-1:0] RX_ST_DATA,
    input [0:0] RX_ST_EOP,
    input [0:0] RX_ST_SOP, 
    input [0:0] RX_ST_VALID,
    output RX_ST_READY,
    input [0:0] RX_ST_EMPTY,

    output [C_PCI_DATA_WIDTH-1:0] TX_ST_DATA,
    output [0:0] TX_ST_VALID,
    input TX_ST_READY,
    output [0:0] TX_ST_EOP,
    output [0:0] TX_ST_SOP,
    output [0:0] TX_ST_EMPTY,
    input [31:0] TL_CFG_CTL,
    input [3:0] TL_CFG_ADD,
    input [52:0] TL_CFG_STS,
    input [7:0] 			       KO_CPL_SPC_HEADER,
    input [11:0] 			       KO_CPL_SPC_DATA,

    input APP_MSI_ACK,
    output APP_MSI_REQ,

    // RIFFA Signals
	input [C_NUM_CHNL-1:0] CHNL_RX_CLK, 
	output [C_NUM_CHNL-1:0] CHNL_RX, 
	input [C_NUM_CHNL-1:0] CHNL_RX_ACK, 
	output [C_NUM_CHNL-1:0] CHNL_RX_LAST, 
	output [(C_NUM_CHNL*32)-1:0] CHNL_RX_LEN, 
	output [(C_NUM_CHNL*31)-1:0] CHNL_RX_OFF, 
	output [(C_NUM_CHNL*C_PCI_DATA_WIDTH)-1:0] CHNL_RX_DATA, 
	output [C_NUM_CHNL-1:0] CHNL_RX_DATA_VALID, 
	input [C_NUM_CHNL-1:0] CHNL_RX_DATA_REN,
	
	input [C_NUM_CHNL-1:0] CHNL_TX_CLK, 
	input [C_NUM_CHNL-1:0] CHNL_TX, 
	output [C_NUM_CHNL-1:0] CHNL_TX_ACK,
	input [C_NUM_CHNL-1:0] CHNL_TX_LAST, 
	input [(C_NUM_CHNL*32)-1:0] CHNL_TX_LEN, 
	input [(C_NUM_CHNL*31)-1:0] CHNL_TX_OFF, 
	input [(C_NUM_CHNL*C_PCI_DATA_WIDTH)-1:0] CHNL_TX_DATA, 
	input [C_NUM_CHNL-1:0] CHNL_TX_DATA_VALID, 
	output [C_NUM_CHNL-1:0] CHNL_TX_DATA_REN
);

   wire INTR_LEGACY_RDY;        
   wire INTR_MSI_RDY;           
   wire INTR_MSI_REQUEST;
   wire CONFIG_BUS_MASTER_ENABLE;
   wire CONFIG_INTERRUPT_MSIENABLE;
   wire [1:0] CONFIG_LINK_RATE;       
   wire [2:0] CONFIG_MAX_PAYLOAD_SIZE;
   wire [2:0] CONFIG_MAX_READ_REQUEST_SIZE;
   wire [5:0] CONFIG_LINK_WIDTH;      
   wire [15:0] CONFIG_COMPLETER_ID;    
   wire [11:0] CONFIG_MAX_CPL_DATA; // Receive credit limit for data
   wire [7:0] CONFIG_MAX_CPL_HDR; // Receive credit limit for headers
   wire CONFIG_CPL_BOUNDARY_SEL; // Read completion boundary (0=64 bytes, 1=128 byt
   wire RX_DATA_READY;
   wire RX_DATA_VALID;          
   wire RX_TLP_END_FLAG;        
   wire RX_TLP_ERROR_POISON;    
   wire RX_TLP_START_FLAG;      
   wire [3:0] RX_TLP_END_OFFSET;      
   wire [3:0] RX_TLP_START_OFFSET;    
   wire [C_PCI_DATA_WIDTH-1:0] RX_DATA;         
   wire [(C_PCI_DATA_WIDTH/8)-1:0] RX_DATA_BYTE_ENABLE;

   wire TX_DATA_READY;          
   wire TX_DATA_VALID;
   wire TX_TLP_END_FLAG;
   wire TX_TLP_ERROR_POISON;
   wire TX_TLP_START_FLAG;
   wire [C_PCI_DATA_WIDTH-1:0] TX_DATA;
   wire [(C_PCI_DATA_WIDTH/8)-1:0] TX_DATA_BYTE_ENABLE;

   translation_layer
     #(
      // Parameters
      .C_ALTERA(C_ALTERA),
      .C_PCI_DATA_WIDTH(C_PCI_DATA_WIDTH))
     translation_layer_inst
       (
        // Outputs
        .M_AXIS_RX_TREADY               (M_AXIS_RX_TREADY),
        .S_AXIS_TX_TDATA                (S_AXIS_TX_TDATA[C_PCI_DATA_WIDTH-1:0]),
        .S_AXIS_TX_TKEEP                (S_AXIS_TX_TKEEP[(C_PCI_DATA_WIDTH/8)-1:0]),
        .S_AXIS_TX_TLAST                (S_AXIS_TX_TLAST),
        .S_AXIS_TX_TVALID               (S_AXIS_TX_TVALID),
        .S_AXIS_SRC_DSC                 (S_AXIS_SRC_DSC),
        .CFG_INTERRUPT                  (CFG_INTERRUPT),
        .RX_ST_READY                    (RX_ST_READY),
        .TX_ST_DATA                     (TX_ST_DATA[C_PCI_DATA_WIDTH-1:0]),
        .TX_ST_VALID                    (TX_ST_VALID[0:0]),
        .TX_ST_EOP                      (TX_ST_EOP[0:0]),
        .TX_ST_SOP                      (TX_ST_SOP[0:0]),
        .TX_ST_EMPTY                    (TX_ST_EMPTY[0:0]),
        .APP_MSI_REQ                    (APP_MSI_REQ),
        .RX_DATA                        (RX_DATA[C_PCI_DATA_WIDTH-1:0]),
        .RX_DATA_VALID                  (RX_DATA_VALID),
        .RX_DATA_BYTE_ENABLE            (RX_DATA_BYTE_ENABLE[(C_PCI_DATA_WIDTH/8)-1:0]),
        .RX_TLP_END_FLAG                (RX_TLP_END_FLAG),
        .RX_TLP_END_OFFSET              (RX_TLP_END_OFFSET[3:0]),
        .RX_TLP_START_FLAG              (RX_TLP_START_FLAG),
        .RX_TLP_START_OFFSET            (RX_TLP_START_OFFSET[3:0]),
        .RX_TLP_ERROR_POISON            (RX_TLP_ERROR_POISON),
        .TX_DATA_READY                  (TX_DATA_READY),
        .CONFIG_COMPLETER_ID            (CONFIG_COMPLETER_ID[15:0]),
        .CONFIG_BUS_MASTER_ENABLE       (CONFIG_BUS_MASTER_ENABLE),
        .CONFIG_LINK_WIDTH              (CONFIG_LINK_WIDTH[5:0]),
        .CONFIG_LINK_RATE               (CONFIG_LINK_RATE[1:0]),
        .CONFIG_MAX_READ_REQUEST_SIZE   (CONFIG_MAX_READ_REQUEST_SIZE[2:0]),
        .CONFIG_MAX_PAYLOAD_SIZE        (CONFIG_MAX_PAYLOAD_SIZE[2:0]),
        .CONFIG_INTERRUPT_MSIENABLE     (CONFIG_INTERRUPT_MSIENABLE),
      	.CONFIG_MAX_CPL_DATA	      	(CONFIG_MAX_CPL_DATA[11:0]),
      	.CONFIG_MAX_CPL_HDR	      		(CONFIG_MAX_CPL_HDR[7:0]),
      	.CONFIG_CPL_BOUNDARY_SEL	    (CONFIG_CPL_BOUNDARY_SEL),
        .INTR_MSI_RDY                   (INTR_MSI_RDY),
        // Inputs
        .CLK                            (CLK),
        .RST_IN                         (RST_IN),
        .M_AXIS_RX_TDATA                (M_AXIS_RX_TDATA[C_PCI_DATA_WIDTH-1:0]),
        .M_AXIS_RX_TKEEP                (M_AXIS_RX_TKEEP[(C_PCI_DATA_WIDTH/8)-1:0]),
        .M_AXIS_RX_TLAST                (M_AXIS_RX_TLAST),
        .M_AXIS_RX_TVALID               (M_AXIS_RX_TVALID),
        .IS_SOF                         (IS_SOF[4:0]),
        .IS_EOF                         (IS_EOF[4:0]),
        .RERR_FWD                       (RERR_FWD),
        .S_AXIS_TX_TREADY               (S_AXIS_TX_TREADY),
        .COMPLETER_ID                   (COMPLETER_ID[15:0]),
        .CFG_BUS_MSTR_ENABLE            (CFG_BUS_MSTR_ENABLE),
        .CFG_LINK_WIDTH                 (CFG_LINK_WIDTH[5:0]),
        .CFG_LINK_RATE                  (CFG_LINK_RATE[1:0]),
        .CFG_MAX_READ_REQUEST_SIZE      (MAX_READ_REQUEST_SIZE[2:0]),
        .CFG_MAX_PAYLOAD_SIZE           (MAX_PAYLOAD_SIZE[2:0]),
        .CFG_INTERRUPT_MSIEN            (CFG_INTERRUPT_MSIEN),
        .CFG_INTERRUPT_RDY              (CFG_INTERRUPT_RDY),
      	.RCB			      			(RCB),
      	.MAX_RC_CPLD		      		(MAX_RC_CPLD[11:0]),
      	.MAX_RC_CPLH		      		(MAX_RC_CPLH[7:0]),
        .RX_ST_DATA                     (RX_ST_DATA[C_PCI_DATA_WIDTH-1:0]),
        .RX_ST_EOP                      (RX_ST_EOP[0:0]),
        .RX_ST_SOP                      (RX_ST_SOP[0:0]),
        .RX_ST_VALID                    (RX_ST_VALID[0:0]),
        .RX_ST_EMPTY                    (RX_ST_EMPTY[0:0]),
        .TX_ST_READY                    (TX_ST_READY),
        .TL_CFG_CTL                     (TL_CFG_CTL[31:0]),
        .TL_CFG_ADD                     (TL_CFG_ADD[3:0]),
        .TL_CFG_STS                     (TL_CFG_STS[52:0]),
      	.KO_CPL_SPC_HEADER	      		(KO_CPL_SPC_HEADER[7:0]),
      	.KO_CPL_SPC_DATA		      	(KO_CPL_SPC_DATA[11:0]),
        .APP_MSI_ACK                    (APP_MSI_ACK),
        .RX_DATA_READY                  (RX_DATA_READY),
        .TX_DATA                        (TX_DATA[C_PCI_DATA_WIDTH-1:0]),
        .TX_DATA_BYTE_ENABLE            (TX_DATA_BYTE_ENABLE[(C_PCI_DATA_WIDTH/8)-1:0]),
        .TX_TLP_END_FLAG                (TX_TLP_END_FLAG),
        .TX_TLP_START_FLAG              (TX_TLP_START_FLAG),
        .TX_DATA_VALID                  (TX_DATA_VALID),
        .TX_TLP_ERROR_POISON            (TX_TLP_ERROR_POISON),
        .INTR_MSI_REQUEST               (INTR_MSI_REQUEST));
   
generate
if (C_PCI_DATA_WIDTH == 9'd32) begin : endpoint32
	riffa_endpoint_32 #(
		.C_PCI_DATA_WIDTH(C_PCI_DATA_WIDTH),
		.C_NUM_CHNL(C_NUM_CHNL),
		.C_MAX_READ_REQ_BYTES(C_MAX_READ_REQ_BYTES),
	    .C_TAG_WIDTH(C_TAG_WIDTH),
        .C_ALTERA(C_ALTERA)
	) endpoint (
		.CLK(CLK),
		.RST_IN(RST_IN),
		.RST_OUT(RST_OUT),

		.RX_DATA(RX_DATA),
		.RX_TLP_END_FLAG(RX_TLP_END_FLAG),
		.RX_DATA_VALID(RX_DATA_VALID),
		.RX_DATA_READY(RX_DATA_READY),
		.RX_TLP_ERROR_POISON(RX_TLP_ERROR_POISON),
		
		.TX_DATA(TX_DATA),
		.TX_DATA_BYTE_ENABLE(TX_DATA_BYTE_ENABLE),
		.TX_TLP_END_FLAG(TX_TLP_END_FLAG),
        .TX_TLP_START_FLAG(TX_TLP_START_FLAG),
		.TX_DATA_VALID(TX_DATA_VALID),
		.S_AXIS_SRC_DSC(TX_TLP_ERROR_POISON),
		.TX_DATA_READY(TX_DATA_READY),
		
		.CONFIG_COMPLETER_ID(CONFIG_COMPLETER_ID),
		.CONFIG_BUS_MASTER_ENABLE(CONFIG_BUS_MASTER_ENABLE),	
		.CONFIG_LINK_WIDTH(CONFIG_LINK_WIDTH),
		.CONFIG_LINK_RATE(CONFIG_LINK_RATE),
		.CONFIG_MAX_READ_REQUEST_SIZE(CONFIG_MAX_READ_REQUEST_SIZE),
		.CONFIG_MAX_PAYLOAD_SIZE(CONFIG_MAX_PAYLOAD_SIZE), 
		.CONFIG_INTERRUPT_MSIENABLE(CONFIG_INTERRUPT_MSIENABLE),
	    .CONFIG_MAX_CPL_DATA(CONFIG_MAX_CPL_DATA[11:0]),
	    .CONFIG_MAX_CPL_HDR(CONFIG_MAX_CPL_HDR[7:0]),
	    .CONFIG_CPL_BOUNDARY_SEL(CONFIG_CPL_BOUNDARY_SEL),
		.INTR_MSI_RDY(INTR_MSI_RDY),
		.INTR_MSI_REQUEST(INTR_MSI_REQUEST),
		
		.CHNL_RX_CLK(CHNL_RX_CLK), 
		.CHNL_RX(CHNL_RX), 
		.CHNL_RX_ACK(CHNL_RX_ACK),
		.CHNL_RX_LAST(CHNL_RX_LAST), 
		.CHNL_RX_LEN(CHNL_RX_LEN), 
		.CHNL_RX_OFF(CHNL_RX_OFF), 
		.CHNL_RX_DATA(CHNL_RX_DATA), 
		.CHNL_RX_DATA_VALID(CHNL_RX_DATA_VALID), 
		.CHNL_RX_DATA_REN(CHNL_RX_DATA_REN),
		
		.CHNL_TX_CLK(CHNL_TX_CLK), 
		.CHNL_TX(CHNL_TX), 
		.CHNL_TX_ACK(CHNL_TX_ACK),
		.CHNL_TX_LAST(CHNL_TX_LAST), 
		.CHNL_TX_LEN(CHNL_TX_LEN), 
		.CHNL_TX_OFF(CHNL_TX_OFF), 
		.CHNL_TX_DATA(CHNL_TX_DATA), 
		.CHNL_TX_DATA_VALID(CHNL_TX_DATA_VALID), 
		.CHNL_TX_DATA_REN(CHNL_TX_DATA_REN)
	);
end
else if (C_PCI_DATA_WIDTH == 9'd64) begin : endpoint64
	riffa_endpoint_64 #(
		.C_PCI_DATA_WIDTH(C_PCI_DATA_WIDTH),
		.C_NUM_CHNL(C_NUM_CHNL),
		.C_MAX_READ_REQ_BYTES(C_MAX_READ_REQ_BYTES),
		.C_TAG_WIDTH(C_TAG_WIDTH),
        .C_ALTERA(C_ALTERA)
	) endpoint (
		.CLK(CLK),
		.RST_IN(RST_IN),
		.RST_OUT(RST_OUT),

		.RX_DATA(RX_DATA),
		.RX_DATA_BYTE_ENABLE(RX_DATA_BYTE_ENABLE),
		.RX_TLP_END_FLAG(RX_TLP_END_FLAG),
        .TX_TLP_START_FLAG(TX_TLP_START_FLAG),
		.RX_DATA_VALID(RX_DATA_VALID),
		.RX_DATA_READY(RX_DATA_READY),
		.RX_TLP_ERROR_POISON(RX_TLP_ERROR_POISON),
		
		.TX_DATA(TX_DATA),
		.TX_DATA_BYTE_ENABLE(TX_DATA_BYTE_ENABLE),
		.TX_TLP_END_FLAG(TX_TLP_END_FLAG),
		.TX_DATA_VALID(TX_DATA_VALID),
		.S_AXIS_SRC_DSC(TX_TLP_ERROR_POISON),
		.TX_DATA_READY(TX_DATA_READY),
		
		.CONFIG_COMPLETER_ID(CONFIG_COMPLETER_ID),
		.CONFIG_BUS_MASTER_ENABLE(CONFIG_BUS_MASTER_ENABLE),	
		.CONFIG_LINK_WIDTH(CONFIG_LINK_WIDTH),
		.CONFIG_LINK_RATE(CONFIG_LINK_RATE),
		.CONFIG_MAX_READ_REQUEST_SIZE(CONFIG_MAX_READ_REQUEST_SIZE),
		.CONFIG_MAX_PAYLOAD_SIZE(CONFIG_MAX_PAYLOAD_SIZE), 
		.CONFIG_INTERRUPT_MSIENABLE(CONFIG_INTERRUPT_MSIENABLE),
	    .CONFIG_MAX_CPL_DATA(CONFIG_MAX_CPL_DATA[11:0]),
	    .CONFIG_MAX_CPL_HDR(CONFIG_MAX_CPL_HDR[7:0]),
	    .CONFIG_CPL_BOUNDARY_SEL(CONFIG_CPL_BOUNDARY_SEL),
		.INTR_MSI_RDY(INTR_MSI_RDY),
		.INTR_MSI_REQUEST(INTR_MSI_REQUEST),
		
		.CHNL_RX_CLK(CHNL_RX_CLK), 
		.CHNL_RX(CHNL_RX), 
		.CHNL_RX_ACK(CHNL_RX_ACK),
		.CHNL_RX_LAST(CHNL_RX_LAST), 
		.CHNL_RX_LEN(CHNL_RX_LEN), 
		.CHNL_RX_OFF(CHNL_RX_OFF), 
		.CHNL_RX_DATA(CHNL_RX_DATA), 
		.CHNL_RX_DATA_VALID(CHNL_RX_DATA_VALID), 
		.CHNL_RX_DATA_REN(CHNL_RX_DATA_REN),
		
		.CHNL_TX_CLK(CHNL_TX_CLK), 
		.CHNL_TX(CHNL_TX), 
		.CHNL_TX_ACK(CHNL_TX_ACK),
		.CHNL_TX_LAST(CHNL_TX_LAST), 
		.CHNL_TX_LEN(CHNL_TX_LEN), 
		.CHNL_TX_OFF(CHNL_TX_OFF), 
		.CHNL_TX_DATA(CHNL_TX_DATA), 
		.CHNL_TX_DATA_VALID(CHNL_TX_DATA_VALID), 
		.CHNL_TX_DATA_REN(CHNL_TX_DATA_REN)
	);
end
else if (C_PCI_DATA_WIDTH == 9'd128) begin : endpoint128
	riffa_endpoint_128 #(
		.C_PCI_DATA_WIDTH(C_PCI_DATA_WIDTH),
		.C_NUM_CHNL(C_NUM_CHNL),
		.C_MAX_READ_REQ_BYTES(C_MAX_READ_REQ_BYTES),
		.C_TAG_WIDTH(C_TAG_WIDTH),
        .C_ALTERA(C_ALTERA)
	) endpoint (
		.CLK(CLK),
		.RST_IN(RST_IN),
		.RST_OUT(RST_OUT),
		
		.RX_DATA(RX_DATA),
		.RX_DATA_VALID(RX_DATA_VALID),
		.RX_DATA_READY(RX_DATA_READY),
        .RX_TLP_END_FLAG(RX_TLP_END_FLAG),
        .RX_TLP_START_FLAG(RX_TLP_START_FLAG),
        .RX_TLP_END_OFFSET(RX_TLP_END_OFFSET),
        .RX_TLP_START_OFFSET(RX_TLP_START_OFFSET),
		.RX_TLP_ERROR_POISON(RX_TLP_ERROR_POISON),
		
		.TX_DATA(TX_DATA),
		.TX_DATA_BYTE_ENABLE(TX_DATA_BYTE_ENABLE),
		.TX_TLP_END_FLAG(TX_TLP_END_FLAG),
        .TX_TLP_START_FLAG(TX_TLP_START_FLAG),
		.TX_DATA_VALID(TX_DATA_VALID),
		.S_AXIS_SRC_DSC(TX_TLP_ERROR_POISON),
		.TX_DATA_READY(TX_DATA_READY),
		
		.CONFIG_COMPLETER_ID(CONFIG_COMPLETER_ID),
		.CONFIG_BUS_MASTER_ENABLE(CONFIG_BUS_MASTER_ENABLE),	
		.CONFIG_LINK_WIDTH(CONFIG_LINK_WIDTH),
		.CONFIG_LINK_RATE(CONFIG_LINK_RATE),
		.CONFIG_MAX_READ_REQUEST_SIZE(CONFIG_MAX_READ_REQUEST_SIZE),
		.CONFIG_MAX_PAYLOAD_SIZE(CONFIG_MAX_PAYLOAD_SIZE), 
		.CONFIG_INTERRUPT_MSIENABLE(CONFIG_INTERRUPT_MSIENABLE),
	    .CONFIG_MAX_CPL_DATA(CONFIG_MAX_CPL_DATA[11:0]),
	    .CONFIG_MAX_CPL_HDR(CONFIG_MAX_CPL_HDR[7:0]),
	    .CONFIG_CPL_BOUNDARY_SEL(CONFIG_CPL_BOUNDARY_SEL),
		.INTR_MSI_RDY(INTR_MSI_RDY),
		.INTR_MSI_REQUEST(INTR_MSI_REQUEST),
		
		.CHNL_RX_CLK(CHNL_RX_CLK), 
		.CHNL_RX(CHNL_RX), 
		.CHNL_RX_ACK(CHNL_RX_ACK),
		.CHNL_RX_LAST(CHNL_RX_LAST), 
		.CHNL_RX_LEN(CHNL_RX_LEN), 
		.CHNL_RX_OFF(CHNL_RX_OFF), 
		.CHNL_RX_DATA(CHNL_RX_DATA), 
		.CHNL_RX_DATA_VALID(CHNL_RX_DATA_VALID), 
		.CHNL_RX_DATA_REN(CHNL_RX_DATA_REN),
		
		.CHNL_TX_CLK(CHNL_TX_CLK), 
		.CHNL_TX(CHNL_TX), 
		.CHNL_TX_ACK(CHNL_TX_ACK),
		.CHNL_TX_LAST(CHNL_TX_LAST), 
		.CHNL_TX_LEN(CHNL_TX_LEN), 
		.CHNL_TX_OFF(CHNL_TX_OFF), 
		.CHNL_TX_DATA(CHNL_TX_DATA), 
		.CHNL_TX_DATA_VALID(CHNL_TX_DATA_VALID), 
		.CHNL_TX_DATA_REN(CHNL_TX_DATA_REN)
	);
end
endgenerate

endmodule

