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
// Filename:			riffa_adapter_v6_pcie_v2_5.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Adapts the Xilinx Virtex-6 Integrated Block for PCI 
//						Express module (v6_pcie_v2_5) to the riffa_endpoint 
//						module.
//						NOTE: You must uncomment the C_NUM_CHNL parameter and
//						set a value as appropriate to your design. See the end
//						of the file for an example of how to connect to 
//						channels. You may bring in any additional signals, but
//						be sure to leave all existing signals connected.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------
`define PCI_EXP_EP_OUI		24'h000A35
`define PCI_EXP_EP_DSN_1	{{8'h1},`PCI_EXP_EP_OUI}
`define PCI_EXP_EP_DSN_2	32'h00000001

module pcie_app_v6 #(
	parameter DQ_WIDTH = 64,
	parameter C_DATA_WIDTH = 9'd64,
	parameter KEEP_WIDTH = (C_DATA_WIDTH/8),
	parameter C_NUM_CHNL = 4'd1, 			// Number of RIFFA channels (set as needed: 1-12)
	parameter C_MAX_READ_REQ_BYTES = 512,	// Max size of read requests (in bytes). Setting this higher than PCIe Endpoint's MAX READ value just wastes resources
	parameter C_TAG_WIDTH = 5 				// Number of outstanding tag requests
)
(
	input						user_clk,
	input						user_reset,
	input						user_lnk_up,

	// Tx
	input	[5:0]				tx_buf_av,
	input						tx_cfg_req,
	input						tx_err_drop,
	output						tx_cfg_gnt,

	input						s_axis_tx_tready,
	output	[C_DATA_WIDTH-1:0]	s_axis_tx_tdata,
	output	[KEEP_WIDTH-1:0]	s_axis_tx_tkeep,
	output	[3:0]				s_axis_tx_tuser,
	output						s_axis_tx_tlast,
	output						s_axis_tx_tvalid,

	// Rx
	output						rx_np_ok,
	input	[C_DATA_WIDTH-1:0]	m_axis_rx_tdata,
	input	[KEEP_WIDTH-1:0]	m_axis_rx_tkeep,
	input						m_axis_rx_tlast,
	input						m_axis_rx_tvalid,
	output						m_axis_rx_tready,
	input	[21:0]				m_axis_rx_tuser,

	// Flow Control
	input	[11:0]				fc_cpld,
	input	[7:0]				fc_cplh,
	input	[11:0]				fc_npd,
	input	[7:0]				fc_nph,
	input	[11:0]				fc_pd,
	input	[7:0]				fc_ph,
	output	[2:0]				fc_sel,

	// CFG
	input	[31:0]				cfg_do,
	input						cfg_rd_wr_done,
	output	[31:0]				cfg_di,
	output	[3:0]				cfg_byte_en,
	output	[9:0]				cfg_dwaddr,
	output						cfg_wr_en,
	output						cfg_rd_en,

	output						cfg_err_cor,
	output						cfg_err_ur,
	output						cfg_err_ecrc,
	output						cfg_err_cpl_timeout,
	output						cfg_err_cpl_abort,
	output						cfg_err_cpl_unexpect,
	output						cfg_err_posted,
	output						cfg_err_locked,
	output	[47:0]				cfg_err_tlp_cpl_header,
	input						cfg_err_cpl_rdy,
	output						cfg_interrupt,
	input						cfg_interrupt_rdy,
	output						cfg_interrupt_assert,
	output	[7:0]				cfg_interrupt_di,
	input	[7:0]				cfg_interrupt_do,
	input	[2:0]				cfg_interrupt_mmenable,
	input						cfg_interrupt_msienable,
	input						cfg_interrupt_msixenable,
	input						cfg_interrupt_msixfm,
	output						cfg_turnoff_ok,
	input						cfg_to_turnoff,
	output						cfg_trn_pending,
	output						cfg_pm_wake,
	input	[7:0]				cfg_bus_number,
	input	[4:0]				cfg_device_number,
	input	[2:0]				cfg_function_number,
	input	[15:0]				cfg_status,
	input	[15:0]				cfg_command,
	input	[15:0]				cfg_dstatus,
	input	[15:0]				cfg_dcommand,
	input	[15:0]				cfg_lstatus,
	input	[15:0]				cfg_lcommand,
	input	[15:0]				cfg_dcommand2,
	input	[2:0]				cfg_pcie_link_state,

	output	[1:0]				pl_directed_link_change,
	input	[5:0]				pl_ltssm_state,
	output	[1:0]				pl_directed_link_width,
	output						pl_directed_link_speed,
	output						pl_directed_link_auton,
	output						pl_upstream_prefer_deemph,
	input	[1:0]				pl_sel_link_width,
	input						pl_sel_link_rate,
	input						pl_link_gen2_capable,
	input						pl_link_partner_gen2_supported,
	input	[2:0]				pl_initial_link_width,
	input						pl_link_upcfg_capable,
	input	[1:0]				pl_lane_reversal_mode,
	input						pl_received_hot_rst,

	output	[63:0]				cfg_dsn,
	
	input app_clk,
	output  app_en,
	input app_ack,
	output[31:0] app_instr,
	
	//Data read back Interface
	input rdback_fifo_empty,
	output rdback_fifo_rden,
	input[DQ_WIDTH*4 - 1:0] rdback_data
);

////////////////////////////////////
// START RIFFA CODE (do not edit)
////////////////////////////////////

// Core input tie-offs
assign fc_sel = 3'b001; 						// Always read receive credit limits

assign rx_np_ok = 1'b1;							// Allow Reception of Non-posted Traffic
assign s_axis_tx_tuser[0] = 1'b0;				// Unused for V7
assign s_axis_tx_tuser[1] = 1'b0;				// Error forward packet
assign s_axis_tx_tuser[2] = 1'b1;				// We support stream packet (cut-through mode)

assign tx_cfg_gnt = 1'b1;						// Always allow to transmit internally generated TLPs

assign cfg_err_cor = 1'b0;						// Never report Correctable Error
assign cfg_err_ur = 1'b0;						// Never report UR
assign cfg_err_ecrc = 1'b0;						// Never report ECRC Error
assign cfg_err_cpl_timeout = 1'b0;				// Never report Completion Timeout
assign cfg_err_cpl_abort = 1'b0;				// Never report Completion Abort
assign cfg_err_cpl_unexpect = 1'b0;				// Never report unexpected completion
assign cfg_err_posted = 1'b0;					// Not sending back CPLs for app level errors
assign cfg_err_locked = 1'b0;					// Never qualify cfg_err_ur or cfg_err_cpl_abort

assign cfg_err_tlp_cpl_header = 48'h0;			// Not sending back CLPs for app level errors

assign cfg_trn_pending = 1'b0;					// Not trying to recover from missing request data... 

assign cfg_err_atomic_egress_blocked = 1'b0;	// Never report Atomic TLP blocked
assign cfg_err_internal_cor = 1'b0;				// Never report internal error occurred
assign cfg_err_malformed = 1'b0;				// Never report malformed error
assign cfg_err_mc_blocked = 1'b0;				// Never report multi-cast TLP blocked
assign cfg_err_poisoned = 1'b0;					// Never report poisoned TLP received
assign cfg_err_norecovery = 1'b0;				// Never qualify cfg_err_poisoned or cfg_err_cpl_timeout
assign cfg_err_acs = 1'b0;						// Never report an ACS violation
assign cfg_err_internal_uncor = 1'b0;			// Never report internal uncorrectable error
assign cfg_pm_halt_aspm_l0s = 1'b0;				// Allow entry into L0s
assign cfg_pm_halt_aspm_l1 = 1'b0;				// Allow entry into L1
assign cfg_pm_force_state_en	= 1'b0;			// Do not qualify cfg_pm_force_state
assign cfg_pm_force_state	= 2'b00;				// Do not move force core into specific PM state

assign cfg_err_aer_headerlog = 128'h0;			// Zero out the AER Header Log
assign cfg_aer_interrupt_msgnum = 5'b00000;		// Zero out the AER Root Error Status Register

assign cfg_pciecap_interrupt_msgnum = 5'b00000;	// Zero out Interrupt Message Number

assign cfg_interrupt_di = 8'b0; 				// Not using multiple vector MSI interrupts (just single vector)
assign cfg_interrupt_assert = 1'b0;				// Not using legacy interrupts

assign pl_directed_link_change = 2'b00;			// Never initiate link change
assign pl_directed_link_width = 2'b00;			// Zero out directed link width
assign pl_directed_link_speed = 1'b0;			// Zero out directed link speed
assign pl_directed_link_auton = 1'b0;			// Zero out link autonomous input
assign pl_upstream_prefer_deemph = 1'b1;		// Zero out preferred de-emphasis of upstream port

assign cfg_dwaddr = 0; 							// Not allowing any config space reads/writes
assign cfg_rd_en = 0; 							// Not supporting config space reads
assign cfg_di = 0;								// Not supporting config space writes
assign cfg_byte_en = 4'h0;						// Not supporting config space writes
assign cfg_wr_en = 0;							// Not supporting config space writes
assign cfg_dsn = {`PCI_EXP_EP_DSN_2, `PCI_EXP_EP_DSN_1};	// Assign the input DSN

assign cfg_pm_wake = 1'b0; 						// Not supporting PM_PME Message
assign cfg_turnoff_ok = 1'b0;					// Currently don't support power down

// RIFFA channel interface
wire	[C_NUM_CHNL-1:0]						chnl_rx_clk;
wire	[C_NUM_CHNL-1:0]						chnl_rx;
wire	[C_NUM_CHNL-1:0]						chnl_rx_ack;
wire	[C_NUM_CHNL-1:0]						chnl_rx_last;
wire	[(C_NUM_CHNL*32)-1:0]					chnl_rx_len;
wire	[(C_NUM_CHNL*31)-1:0]					chnl_rx_off;
wire	[(C_NUM_CHNL*C_DATA_WIDTH)-1:0]			chnl_rx_data;
wire	[C_NUM_CHNL-1:0]						chnl_rx_data_valid;
wire	[C_NUM_CHNL-1:0]						chnl_rx_data_ren;
	
wire	[C_NUM_CHNL-1:0]						chnl_tx_clk;
wire	[C_NUM_CHNL-1:0]						chnl_tx;
wire	[C_NUM_CHNL-1:0]						chnl_tx_ack;
wire	[C_NUM_CHNL-1:0]						chnl_tx_last;
wire	[(C_NUM_CHNL*32)-1:0]					chnl_tx_len;
wire	[(C_NUM_CHNL*31)-1:0]					chnl_tx_off;
wire	[(C_NUM_CHNL*C_DATA_WIDTH)-1:0]			chnl_tx_data;
wire	[C_NUM_CHNL-1:0]						chnl_tx_data_valid;
wire	[C_NUM_CHNL-1:0]						chnl_tx_data_ren;

// Create a synchronous reset
wire			user_lnk_up_int1;
wire			user_reset_intl;
wire			reset = (!user_lnk_up_int1 | user_reset_intl);
FDCP #(.INIT(1'b1)) user_lnk_up_n_int_i (
	.Q (user_lnk_up_int1), 
	.D (user_lnk_up), 
	.C (user_clk), 
	.CLR (1'b0), 
	.PRE (1'b0)
);
FDCP #(.INIT(1'b1)) user_reset_n_i (
	.Q (user_reset_intl),
	.D (user_reset),
	.C (user_clk),
	.CLR (1'b0),
	.PRE (1'b0)
);

// RIFFA Endpoint
reg				cfg_bus_mstr_enable;
reg		[2:0]	cfg_prg_max_payload_size;
reg		[2:0]	cfg_max_rd_req_size;
reg		[5:0]	cfg_link_width;
reg		[1:0]	cfg_link_rate;
reg		[11:0]	rc_cpld;
reg		[7:0]	rc_cplh;
reg		rcb;
wire	[15:0]	cfg_completer_id = {cfg_bus_number, cfg_device_number, cfg_function_number};
wire	[6:0]	m_axis_rbar_hit = m_axis_rx_tuser[8:2];
wire	[4:0]	is_sof = m_axis_rx_tuser[14:10];
wire	[4:0]	is_eof = m_axis_rx_tuser[21:17];
wire			rerr_fwd = m_axis_rx_tuser[1];
wire			riffa_reset;
wire	[C_DATA_WIDTH-1:0] bus_zero = {C_DATA_WIDTH{1'b0}};

always @(posedge user_clk) begin
	cfg_bus_mstr_enable <= #1 cfg_command[2];
	cfg_prg_max_payload_size <= #1 cfg_dcommand[7:5];
	cfg_max_rd_req_size <= #1 cfg_dcommand[14:12];
	cfg_link_width <= #1 cfg_lstatus[9:4];
	cfg_link_rate <= #1 cfg_lstatus[1:0];
	rc_cpld <= #1 fc_cpld;
	rc_cplh <= #1 fc_cplh;
	rcb <= #1 cfg_lcommand[3];
end

riffa_endpoint #(
	.C_PCI_DATA_WIDTH(C_DATA_WIDTH),
	.C_NUM_CHNL(C_NUM_CHNL),
	.C_MAX_READ_REQ_BYTES(C_MAX_READ_REQ_BYTES),
	.C_TAG_WIDTH(C_TAG_WIDTH),
	.C_ALTERA(0)
) endpoint (
	.CLK(user_clk),
	.RST_IN(reset),
	.RST_OUT(riffa_reset),

	.M_AXIS_RX_TDATA(m_axis_rx_tdata),
	.M_AXIS_RX_TKEEP(m_axis_rx_tkeep),
	.M_AXIS_RX_TLAST(m_axis_rx_tlast),
	.M_AXIS_RX_TVALID(m_axis_rx_tvalid),
	.M_AXIS_RX_TREADY(m_axis_rx_tready),
	.IS_SOF(is_sof),
	.IS_EOF(is_eof),
	.RERR_FWD(rerr_fwd),
	
	.S_AXIS_TX_TDATA(s_axis_tx_tdata),
	.S_AXIS_TX_TKEEP(s_axis_tx_tkeep),
	.S_AXIS_TX_TLAST(s_axis_tx_tlast),
	.S_AXIS_TX_TVALID(s_axis_tx_tvalid),
	.S_AXIS_SRC_DSC(s_axis_tx_tuser[3]),
	.S_AXIS_TX_TREADY(s_axis_tx_tready),

	.COMPLETER_ID(cfg_completer_id),
	.CFG_BUS_MSTR_ENABLE(cfg_bus_mstr_enable),
	.CFG_LINK_WIDTH(cfg_link_width),
	.CFG_LINK_RATE(cfg_link_rate),
	.MAX_READ_REQUEST_SIZE(cfg_max_rd_req_size),
	.MAX_PAYLOAD_SIZE(cfg_prg_max_payload_size), 
	.CFG_INTERRUPT_MSIEN(cfg_interrupt_msienable),
	.CFG_INTERRUPT_RDY(cfg_interrupt_rdy),
	.CFG_INTERRUPT(cfg_interrupt),
	.RCB(rcb),
	.MAX_RC_CPLD(rc_cpld),
	.MAX_RC_CPLH(rc_cplh),
	
	.RX_ST_DATA(bus_zero),
	.RX_ST_EOP(1'd0),
	.RX_ST_SOP(1'd0),
	.RX_ST_VALID(1'd0),
	.RX_ST_READY(),
	.RX_ST_EMPTY(1'd0),

	.TX_ST_DATA(),
	.TX_ST_VALID(),
	.TX_ST_READY(1'd0),
	.TX_ST_EOP(),
	.TX_ST_SOP(),
	.TX_ST_EMPTY(),
	.TL_CFG_CTL(32'd0),
	.TL_CFG_ADD(4'd0),
	.TL_CFG_STS(53'd0),

	.APP_MSI_ACK(1'd0),
	.APP_MSI_REQ(),

	.CHNL_RX_CLK(chnl_rx_clk), 
	.CHNL_RX(chnl_rx), 
	.CHNL_RX_ACK(chnl_rx_ack),
	.CHNL_RX_LAST(chnl_rx_last), 
	.CHNL_RX_LEN(chnl_rx_len), 
	.CHNL_RX_OFF(chnl_rx_off), 
	.CHNL_RX_DATA(chnl_rx_data), 
	.CHNL_RX_DATA_VALID(chnl_rx_data_valid), 
	.CHNL_RX_DATA_REN(chnl_rx_data_ren),
	
	.CHNL_TX_CLK(chnl_tx_clk), 
	.CHNL_TX(chnl_tx), 
	.CHNL_TX_ACK(chnl_tx_ack),
	.CHNL_TX_LAST(chnl_tx_last), 
	.CHNL_TX_LEN(chnl_tx_len), 
	.CHNL_TX_OFF(chnl_tx_off), 
	.CHNL_TX_DATA(chnl_tx_data), 
	.CHNL_TX_DATA_VALID(chnl_tx_data_valid), 
	.CHNL_TX_DATA_REN(chnl_tx_data_ren)
);
////////////////////////////////////
// END RIFFA CODE
////////////////////////////////////

////////////////////////////////////
// START USER CODE (do edit)
////////////////////////////////////

// Instantiate and assign modules to RIFFA channels.

// The example below connects C_NUM_CHNL instances of the same
// module to each RIFFA channel. Your design will likely not
// do the same. You should feel free to manually instantiate
// your custom IP cores here and remove the code below.
/*
genvar i;
generate
	for (i = 0; i < C_NUM_CHNL; i = i + 1) begin : test_channels
		chnl_tester #(C_DATA_WIDTH) module1 (
			.CLK(user_clk),
			.RST(riffa_reset),	// riffa_reset includes riffa_endpoint resets
			// Rx interface
			.CHNL_RX_CLK(chnl_rx_clk[i]), 
			.CHNL_RX(chnl_rx[i]), 
			.CHNL_RX_ACK(chnl_rx_ack[i]), 
			.CHNL_RX_LAST(chnl_rx_last[i]), 
			.CHNL_RX_LEN(chnl_rx_len[32*i +:32]), 
			.CHNL_RX_OFF(chnl_rx_off[31*i +:31]), 
			.CHNL_RX_DATA(chnl_rx_data[C_DATA_WIDTH*i +:C_DATA_WIDTH]), 
			.CHNL_RX_DATA_VALID(chnl_rx_data_valid[i]), 
			.CHNL_RX_DATA_REN(chnl_rx_data_ren[i]),
			// Tx interface
			.CHNL_TX_CLK(chnl_tx_clk[i]), 
			.CHNL_TX(chnl_tx[i]), 
			.CHNL_TX_ACK(chnl_tx_ack[i]), 
			.CHNL_TX_LAST(chnl_tx_last[i]), 
			.CHNL_TX_LEN(chnl_tx_len[32*i +:32]), 
			.CHNL_TX_OFF(chnl_tx_off[31*i +:31]), 
			.CHNL_TX_DATA(chnl_tx_data[C_DATA_WIDTH*i +:C_DATA_WIDTH]), 
			.CHNL_TX_DATA_VALID(chnl_tx_data_valid[i]), 
			.CHNL_TX_DATA_REN(chnl_tx_data_ren[i])
		);	
	end
endgenerate*/

softMC_pcie_app #(.C_PCI_DATA_WIDTH(C_DATA_WIDTH), .DQ_WIDTH(DQ_WIDTH)
) i_soft_pcie(
	.clk(app_clk),
	.rst(riffa_reset),
	
	.CHNL_RX_CLK(chnl_rx_clk), 
	.CHNL_RX(chnl_rx), 
	.CHNL_RX_ACK(chnl_rx_ack), 
	.CHNL_RX_LAST(chnl_rx_last), 
	.CHNL_RX_LEN(chnl_rx_len[0 +:32]), 
	.CHNL_RX_OFF(chnl_rx_off[0 +:31]), 
	.CHNL_RX_DATA(chnl_rx_data[0 +:C_DATA_WIDTH]), 
	.CHNL_RX_DATA_VALID(chnl_rx_data_valid), 
	.CHNL_RX_DATA_REN(chnl_rx_data_ren),
	// Tx interface
	.CHNL_TX_CLK(chnl_tx_clk), 
	.CHNL_TX(chnl_tx), 
	.CHNL_TX_ACK(chnl_tx_ack), 
	.CHNL_TX_LAST(chnl_tx_last), 
	.CHNL_TX_LEN(chnl_tx_len[0 +:32]), 
	.CHNL_TX_OFF(chnl_tx_off[0 +:31]), 
	.CHNL_TX_DATA(chnl_tx_data[0 +:C_DATA_WIDTH]), 
	.CHNL_TX_DATA_VALID(chnl_tx_data_valid), 
	.CHNL_TX_DATA_REN(chnl_tx_data_ren),
	
	
	.app_en(app_en),
	.app_ack(app_ack),
	.app_instr(app_instr),
	
	//Data read back Interface
	.rdback_fifo_empty(rdback_fifo_empty),
	.rdback_fifo_rden(rdback_fifo_rden),
	.rdback_data(rdback_data)
 );

////////////////////////////////////
// END USER CODE
////////////////////////////////////

endmodule
