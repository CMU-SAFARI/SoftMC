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
// Filename:			riffa_top_v6_pcie_v2_5.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Top level module for RIFFA 2.0 reference design for the
//						the Xilinx Virtex-6 Integrated Block for PCI Express 
//						module (v6_pcie_v2_5).
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------
module riffa_top_v6_pcie_v2_5 # (
  parameter        PL_FAST_TRAIN        = "FALSE",
  parameter C_DATA_WIDTH = 32,            // RX/TX interface data width
  parameter DQ_WIDTH = 64,
  // Do not override parameters below this line
  parameter KEEP_WIDTH = C_DATA_WIDTH / 8               // KEEP width
)
(
  output  [7:0]    pci_exp_txp,
  output  [7:0]    pci_exp_txn,
  input   [7:0]    pci_exp_rxp,
  input   [7:0]    pci_exp_rxn,

`ifdef ENABLE_LEDS
  output                                      led_0,
  output                                      led_1,
  output                                      led_2,
`endif
  input                                       sys_clk_p,
  input                                       sys_clk_n,
  input                                       sys_reset_n,
  
  input app_clk,
  output  app_en,
  input app_ack,
	output[31:0] app_instr,
	
	//Data read back Interface
	input rdback_fifo_empty,
	output rdback_fifo_rden,
	input[DQ_WIDTH*4 - 1:0] rdback_data
);

  wire                                        user_clk;
  wire                                        user_reset;
  wire                                        user_lnk_up;

  // Tx
  wire [5:0]                                  tx_buf_av;
  wire                                        tx_cfg_req;
  wire                                        tx_err_drop;
  wire                                        tx_cfg_gnt;
  wire                                        s_axis_tx_tready;
  wire [3:0]                                  s_axis_tx_tuser;
  wire [C_DATA_WIDTH-1:0]                     s_axis_tx_tdata;
  wire [KEEP_WIDTH-1:0]                       s_axis_tx_tkeep;
  wire                                        s_axis_tx_tlast;
  wire                                        s_axis_tx_tvalid;


  // Rx
  wire [C_DATA_WIDTH-1:0]                     m_axis_rx_tdata;
  wire [KEEP_WIDTH-1:0]                       m_axis_rx_tkeep;
  wire                                        m_axis_rx_tlast;
  wire                                        m_axis_rx_tvalid;
  wire                                        m_axis_rx_tready;
  wire  [21:0]                                m_axis_rx_tuser;
  wire                                        rx_np_ok;

  // Flow Control
  wire [11:0]                                 fc_cpld;
  wire [7:0]                                  fc_cplh;
  wire [11:0]                                 fc_npd;
  wire [7:0]                                  fc_nph;
  wire [11:0]                                 fc_pd;
  wire [7:0]                                  fc_ph;
  wire [2:0]                                  fc_sel;


  //-------------------------------------------------------
  // 3. Configuration (CFG) Interface
  //-------------------------------------------------------

  wire [31:0]                                 cfg_do;
  wire                                        cfg_rd_wr_done;
  wire  [31:0]                                cfg_di;
  wire   [3:0]                                cfg_byte_en;
  wire   [9:0]                                cfg_dwaddr;
  wire                                        cfg_wr_en;
  wire                                        cfg_rd_en;

  wire                                        cfg_err_cor;
  wire                                        cfg_err_ur;
  wire                                        cfg_err_ecrc;
  wire                                        cfg_err_cpl_timeout;
  wire                                        cfg_err_cpl_abort;
  wire                                        cfg_err_cpl_unexpect;
  wire                                        cfg_err_posted;
  wire                                        cfg_err_locked;
  wire [47:0]                                 cfg_err_tlp_cpl_header;
  wire                                        cfg_err_cpl_rdy;
  wire                                        cfg_interrupt;
  wire                                        cfg_interrupt_rdy;
  wire                                        cfg_interrupt_assert;
  wire [7:0]                                  cfg_interrupt_di;
  wire [7:0]                                  cfg_interrupt_do;
  wire [2:0]                                  cfg_interrupt_mmenable;
  wire                                        cfg_interrupt_msienable;
  wire                                        cfg_interrupt_msixenable;
  wire                                        cfg_interrupt_msixfm;
  wire                                        cfg_turnoff_ok;
  wire                                        cfg_to_turnoff;
  wire                                        cfg_trn_pending;
  wire                                        cfg_pm_wake;
  wire  [7:0]                                 cfg_bus_number;
  wire  [4:0]                                 cfg_device_number;
  wire  [2:0]                                 cfg_function_number;
  wire [15:0]                                 cfg_status;
  wire [15:0]                                 cfg_command;
  wire [15:0]                                 cfg_dstatus;
  wire [15:0]                                 cfg_dcommand;
  wire [15:0]                                 cfg_lstatus;
  wire [15:0]                                 cfg_lcommand;
  wire [15:0]                                 cfg_dcommand2;
  wire  [2:0]                                 cfg_pcie_link_state;
  wire [63:0]                                 cfg_dsn;

  //-------------------------------------------------------
  // 4. Physical Layer Control and Status (PL) Interface
  //-------------------------------------------------------

  wire [2:0]                                  pl_initial_link_width;
  wire [1:0]                                  pl_lane_reversal_mode;
  wire                                        pl_link_gen2_capable;
  wire                                        pl_link_partner_gen2_supported;
  wire                                        pl_link_upcfg_capable;
  wire [5:0]                                  pl_ltssm_state;
  wire                                        pl_received_hot_rst;
  wire                                        pl_sel_link_rate;
  wire [1:0]                                  pl_sel_link_width;
  wire                                        pl_directed_link_auton;
  wire [1:0]                                  pl_directed_link_change;
  wire                                        pl_directed_link_speed;
  wire [1:0]                                  pl_directed_link_width;
  wire                                        pl_upstream_prefer_deemph;

  wire                                        sys_clk_c;
  wire                                        sys_reset_n_c;

  //-------------------------------------------------------

IBUFDS_GTXE1 refclk_ibuf (.O(sys_clk_c), .ODIV2(), .I(sys_clk_p), .IB(sys_clk_n), .CEB(1'b0));

IBUF   sys_reset_n_ibuf (.O(sys_reset_n_c), .I(sys_reset_n));
`ifdef ENABLE_LEDS
   OBUF   led_0_obuf (.O(led_0), .I(sys_reset_n_c));
   OBUF   led_1_obuf (.O(led_1), .I(user_reset));
   OBUF   led_2_obuf (.O(led_2), .I(!user_lnk_up));
`endif

FDCP #(

  .INIT(1'b1)

) user_lnk_up_n_int_i (

  .Q (user_lnk_up),
  .D (user_lnk_up_int1),
  .C (user_clk),
  .CLR (1'b0),
  .PRE (1'b0)

);

FDCP #(

  .INIT(1'b1)

) user_reset_n_i (

  .Q (user_reset),
  .D (user_reset_int1),
  .C (user_clk),
  .CLR (1'b0),
  .PRE (1'b0)

);

pcie_endpoint #(
  .PL_FAST_TRAIN    ( PL_FAST_TRAIN )
) core (

  //-------------------------------------------------------
  // 1. PCI Express (pci_exp) Interface
  //-------------------------------------------------------

  // Tx
  .pci_exp_txp( pci_exp_txp ),
  .pci_exp_txn( pci_exp_txn ),

  // Rx
  .pci_exp_rxp( pci_exp_rxp ),
  .pci_exp_rxn( pci_exp_rxn ),

  //-------------------------------------------------------
  // 2. AXI-S Interface
  //-------------------------------------------------------

  // Common
  .user_clk_out( user_clk ),
  .user_reset_out( user_reset_int1 ),
  .user_lnk_up( user_lnk_up_int1 ),

  // Tx
  .s_axis_tx_tready( s_axis_tx_tready ),
  .s_axis_tx_tdata( s_axis_tx_tdata ),
  .s_axis_tx_tkeep( s_axis_tx_tkeep ),
  .s_axis_tx_tuser( s_axis_tx_tuser ),
  .s_axis_tx_tlast( s_axis_tx_tlast ),
  .s_axis_tx_tvalid( s_axis_tx_tvalid ),
  .tx_cfg_gnt( tx_cfg_gnt ),
  .tx_cfg_req( tx_cfg_req ),
  .tx_buf_av( tx_buf_av ),
  .tx_err_drop( tx_err_drop ),

  // Rx
  .m_axis_rx_tdata( m_axis_rx_tdata ),
  .m_axis_rx_tkeep( m_axis_rx_tkeep ),
  .m_axis_rx_tlast( m_axis_rx_tlast ),
  .m_axis_rx_tvalid( m_axis_rx_tvalid ),
  .m_axis_rx_tready( m_axis_rx_tready ),
  .m_axis_rx_tuser ( m_axis_rx_tuser ),
  .rx_np_ok( rx_np_ok ),

  // Flow Control
  .fc_cpld( fc_cpld ),
  .fc_cplh( fc_cplh ),
  .fc_npd( fc_npd ),
  .fc_nph( fc_nph ),
  .fc_pd( fc_pd ),
  .fc_ph( fc_ph ),
  .fc_sel( fc_sel ),


  //-------------------------------------------------------
  // 3. Configuration (CFG) Interface
  //-------------------------------------------------------

  .cfg_do( cfg_do ),
  .cfg_rd_wr_done( cfg_rd_wr_done),
  .cfg_di( cfg_di ),
  .cfg_byte_en( cfg_byte_en ),
  .cfg_dwaddr( cfg_dwaddr ),
  .cfg_wr_en( cfg_wr_en ),
  .cfg_rd_en( cfg_rd_en ),

  .cfg_err_cor( cfg_err_cor ),
  .cfg_err_ur( cfg_err_ur ),
  .cfg_err_ecrc( cfg_err_ecrc ),
  .cfg_err_cpl_timeout( cfg_err_cpl_timeout ),
  .cfg_err_cpl_abort( cfg_err_cpl_abort ),
  .cfg_err_cpl_unexpect( cfg_err_cpl_unexpect ),
  .cfg_err_posted( cfg_err_posted ),
  .cfg_err_locked( cfg_err_locked ),
  .cfg_err_tlp_cpl_header( cfg_err_tlp_cpl_header ),
  .cfg_err_cpl_rdy( cfg_err_cpl_rdy ),
  .cfg_interrupt( cfg_interrupt ),
  .cfg_interrupt_rdy( cfg_interrupt_rdy ),
  .cfg_interrupt_assert( cfg_interrupt_assert ),
  .cfg_interrupt_di( cfg_interrupt_di ),
  .cfg_interrupt_do( cfg_interrupt_do ),
  .cfg_interrupt_mmenable( cfg_interrupt_mmenable ),
  .cfg_interrupt_msienable( cfg_interrupt_msienable ),
  .cfg_interrupt_msixenable( cfg_interrupt_msixenable ),
  .cfg_interrupt_msixfm( cfg_interrupt_msixfm ),
  .cfg_turnoff_ok( cfg_turnoff_ok ),
  .cfg_to_turnoff( cfg_to_turnoff ),
  .cfg_trn_pending( cfg_trn_pending ),
  .cfg_pm_wake( cfg_pm_wake ),
  .cfg_bus_number( cfg_bus_number ),
  .cfg_device_number( cfg_device_number ),
  .cfg_function_number( cfg_function_number ),
  .cfg_status( cfg_status ),
  .cfg_command( cfg_command ),
  .cfg_dstatus( cfg_dstatus ),
  .cfg_dcommand( cfg_dcommand ),
  .cfg_lstatus( cfg_lstatus ),
  .cfg_lcommand( cfg_lcommand ),
  .cfg_dcommand2( cfg_dcommand2 ),
  .cfg_pcie_link_state( cfg_pcie_link_state ),
  .cfg_dsn( cfg_dsn ),
  .cfg_pmcsr_pme_en( ),
  .cfg_pmcsr_pme_status( ),
  .cfg_pmcsr_powerstate( ),

  //-------------------------------------------------------
  // 4. Physical Layer Control and Status (PL) Interface
  //-------------------------------------------------------

  .pl_initial_link_width( pl_initial_link_width ),
  .pl_lane_reversal_mode( pl_lane_reversal_mode ),
  .pl_link_gen2_capable( pl_link_gen2_capable ),
  .pl_link_partner_gen2_supported( pl_link_partner_gen2_supported ),
  .pl_link_upcfg_capable( pl_link_upcfg_capable ),
  .pl_ltssm_state( pl_ltssm_state ),
  .pl_received_hot_rst( pl_received_hot_rst ),
  .pl_sel_link_rate( pl_sel_link_rate ),
  .pl_sel_link_width( pl_sel_link_width ),
  .pl_directed_link_auton( pl_directed_link_auton ),
  .pl_directed_link_change( pl_directed_link_change ),
  .pl_directed_link_speed( pl_directed_link_speed ),
  .pl_directed_link_width( pl_directed_link_width ),
  .pl_upstream_prefer_deemph( pl_upstream_prefer_deemph ),

  //-------------------------------------------------------
  // 5. System  (SYS) Interface
  //-------------------------------------------------------

  .sys_clk( sys_clk_c ),
  .sys_reset( !sys_reset_n_c )
);


pcie_app_v6  #(
    .C_DATA_WIDTH( C_DATA_WIDTH ),
    .KEEP_WIDTH( KEEP_WIDTH ),
	 .DQ_WIDTH(DQ_WIDTH)

  )app (

  //-------------------------------------------------------
  // 1. AXI-S Interface
  //-------------------------------------------------------

  // Common
  .user_clk( user_clk ),
  .user_reset( user_reset_int1 ),
  .user_lnk_up( user_lnk_up_int1 ),

  // Tx
  .tx_buf_av( tx_buf_av ),
  .tx_cfg_req( tx_cfg_req ),
  .tx_err_drop( tx_err_drop ),
  .s_axis_tx_tready( s_axis_tx_tready ),
  .s_axis_tx_tdata( s_axis_tx_tdata ),
  .s_axis_tx_tkeep( s_axis_tx_tkeep ),
  .s_axis_tx_tuser( s_axis_tx_tuser ),
  .s_axis_tx_tlast( s_axis_tx_tlast ),
  .s_axis_tx_tvalid( s_axis_tx_tvalid ),
  .tx_cfg_gnt( tx_cfg_gnt ),

  // Rx
  .m_axis_rx_tdata( m_axis_rx_tdata ),
  .m_axis_rx_tkeep( m_axis_rx_tkeep ),
  .m_axis_rx_tlast( m_axis_rx_tlast ),
  .m_axis_rx_tvalid( m_axis_rx_tvalid ),
  .m_axis_rx_tready( m_axis_rx_tready ),
  .m_axis_rx_tuser ( m_axis_rx_tuser ),
  .rx_np_ok( rx_np_ok ),

  // Flow Control
  .fc_cpld( fc_cpld ),
  .fc_cplh( fc_cplh ),
  .fc_npd( fc_npd ),
  .fc_nph( fc_nph ),
  .fc_pd( fc_pd ),
  .fc_ph( fc_ph ),
  .fc_sel( fc_sel ),


  //-------------------------------------------------------
  // 2. Configuration (CFG) Interface
  //-------------------------------------------------------

  .cfg_do( cfg_do ),
  .cfg_rd_wr_done( cfg_rd_wr_done),
  .cfg_di( cfg_di ),
  .cfg_byte_en( cfg_byte_en ),
  .cfg_dwaddr( cfg_dwaddr ),
  .cfg_wr_en( cfg_wr_en ),
  .cfg_rd_en( cfg_rd_en ),

  .cfg_err_cor( cfg_err_cor ),
  .cfg_err_ur( cfg_err_ur ),
  .cfg_err_ecrc( cfg_err_ecrc ),
  .cfg_err_cpl_timeout( cfg_err_cpl_timeout ),
  .cfg_err_cpl_abort( cfg_err_cpl_abort ),
  .cfg_err_cpl_unexpect( cfg_err_cpl_unexpect ),
  .cfg_err_posted( cfg_err_posted ),
  .cfg_err_locked( cfg_err_locked ),
  .cfg_err_tlp_cpl_header( cfg_err_tlp_cpl_header ),
  .cfg_err_cpl_rdy( cfg_err_cpl_rdy ),
  .cfg_interrupt( cfg_interrupt ),
  .cfg_interrupt_rdy( cfg_interrupt_rdy ),
  .cfg_interrupt_assert( cfg_interrupt_assert ),
  .cfg_interrupt_di( cfg_interrupt_di ),
  .cfg_interrupt_do( cfg_interrupt_do ),
  .cfg_interrupt_mmenable( cfg_interrupt_mmenable ),
  .cfg_interrupt_msienable( cfg_interrupt_msienable ),
  .cfg_interrupt_msixenable( cfg_interrupt_msixenable ),
  .cfg_interrupt_msixfm( cfg_interrupt_msixfm ),
  .cfg_turnoff_ok( cfg_turnoff_ok ),
  .cfg_to_turnoff( cfg_to_turnoff ),
  .cfg_trn_pending( cfg_trn_pending ),
  .cfg_pm_wake( cfg_pm_wake ),
  .cfg_bus_number( cfg_bus_number ),
  .cfg_device_number( cfg_device_number ),
  .cfg_function_number( cfg_function_number ),
  .cfg_status( cfg_status ),
  .cfg_command( cfg_command ),
  .cfg_dstatus( cfg_dstatus ),
  .cfg_dcommand( cfg_dcommand ),
  .cfg_lstatus( cfg_lstatus ),
  .cfg_lcommand( cfg_lcommand ),
  .cfg_dcommand2( cfg_dcommand2 ),
  .cfg_pcie_link_state( cfg_pcie_link_state ),
  .cfg_dsn( cfg_dsn ),

  //-------------------------------------------------------
  // 3. Physical Layer Control and Status (PL) Interface
  //-------------------------------------------------------

  .pl_initial_link_width( pl_initial_link_width ),
  .pl_lane_reversal_mode( pl_lane_reversal_mode ),
  .pl_link_gen2_capable( pl_link_gen2_capable ),
  .pl_link_partner_gen2_supported( pl_link_partner_gen2_supported ),
  .pl_link_upcfg_capable( pl_link_upcfg_capable ),
  .pl_ltssm_state( pl_ltssm_state ),
  .pl_received_hot_rst( pl_received_hot_rst ),
  .pl_sel_link_rate( pl_sel_link_rate ),
  .pl_sel_link_width( pl_sel_link_width ),
  .pl_directed_link_auton( pl_directed_link_auton ),
  .pl_directed_link_change( pl_directed_link_change ),
  .pl_directed_link_speed( pl_directed_link_speed ),
  .pl_directed_link_width( pl_directed_link_width ),
  .pl_upstream_prefer_deemph( pl_upstream_prefer_deemph ),
  
  .app_clk(app_clk),
  .app_en(app_en),
  .app_ack(app_ack),
	.app_instr(app_instr),
	
	//Data read back Interface
	.rdback_fifo_empty(rdback_fifo_empty),
	.rdback_fifo_rden(rdback_fifo_rden),
	.rdback_data(rdback_data)

);

endmodule
