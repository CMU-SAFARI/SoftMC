//-----------------------------------------------------------------------------
//
// (c) Copyright 2009-2011 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Virtex-6 Integrated Block for PCI Express
// File       : pcie_gtx_v6.v
// Version    : 2.4
//-- Description: GTX module for Virtex6 PCIe Block
//--
//--
//--
//--------------------------------------------------------------------------------

`timescale 1ns/1ns

module pcie_gtx_v6 #
(

   parameter                         TCQ  = 1,                        // clock to out delay model
   parameter                         NO_OF_LANES = 8,                 // 1 - x1 , 2 - x2 , 4 - x4 , 8 - x8
   parameter                         LINK_CAP_MAX_LINK_SPEED = 4'h1,  // 1 - Gen1, 2 - Gen2
   parameter                         REF_CLK_FREQ = 0,                // 0 - 100 MHz , 1 - 125 MHz , 2 - 250 MHz
   parameter                         PL_FAST_TRAIN = "FALSE"
)
(
   // Pipe Per-Link Signals
   input   wire                      pipe_tx_rcvr_det       ,
   input   wire                      pipe_tx_reset          ,
   input   wire                      pipe_tx_rate           ,
   input   wire                      pipe_tx_deemph         ,
   input   wire [2:0]                pipe_tx_margin         ,
   input   wire                      pipe_tx_swing          ,

   // Pipe Per-Lane Signals - Lane 0
   output  wire [ 1:0]               pipe_rx0_char_is_k     ,
   output  wire [15:0]               pipe_rx0_data          ,
   output  wire                      pipe_rx0_valid         ,
   output  wire                      pipe_rx0_chanisaligned ,
   output  wire [ 2:0]               pipe_rx0_status        ,
   output  wire                      pipe_rx0_phy_status    ,
   output  wire                      pipe_rx0_elec_idle     ,
   input   wire                      pipe_rx0_polarity      ,
   input   wire                      pipe_tx0_compliance    ,
   input   wire [ 1:0]               pipe_tx0_char_is_k     ,
   input   wire [15:0]               pipe_tx0_data          ,
   input   wire                      pipe_tx0_elec_idle     ,
   input   wire [ 1:0]               pipe_tx0_powerdown     ,

   // Pipe Per-Lane Signals - Lane 1
   output  wire [ 1:0]               pipe_rx1_char_is_k     ,
   output  wire [15:0]               pipe_rx1_data          ,
   output  wire                      pipe_rx1_valid         ,
   output  wire                      pipe_rx1_chanisaligned ,
   output  wire [ 2:0]               pipe_rx1_status        ,
   output  wire                      pipe_rx1_phy_status    ,
   output  wire                      pipe_rx1_elec_idle     ,
   input   wire                      pipe_rx1_polarity      ,
   input   wire                      pipe_tx1_compliance    ,
   input   wire [ 1:0]               pipe_tx1_char_is_k     ,
   input   wire [15:0]               pipe_tx1_data          ,
   input   wire                      pipe_tx1_elec_idle     ,
   input   wire [ 1:0]               pipe_tx1_powerdown     ,

   // Pipe Per-Lane Signals - Lane 2
   output  wire [ 1:0]               pipe_rx2_char_is_k     ,
   output  wire [15:0]               pipe_rx2_data          ,
   output  wire                      pipe_rx2_valid         ,
   output  wire                      pipe_rx2_chanisaligned ,
   output  wire [ 2:0]               pipe_rx2_status        ,
   output  wire                      pipe_rx2_phy_status    ,
   output  wire                      pipe_rx2_elec_idle     ,
   input   wire                      pipe_rx2_polarity      ,
   input   wire                      pipe_tx2_compliance    ,
   input   wire [ 1:0]               pipe_tx2_char_is_k     ,
   input   wire [15:0]               pipe_tx2_data          ,
   input   wire                      pipe_tx2_elec_idle     ,
   input   wire [ 1:0]               pipe_tx2_powerdown     ,

   // Pipe Per-Lane Signals - Lane 3
   output  wire [ 1:0]               pipe_rx3_char_is_k     ,
   output  wire [15:0]               pipe_rx3_data          ,
   output  wire                      pipe_rx3_valid         ,
   output  wire                      pipe_rx3_chanisaligned ,
   output  wire [ 2:0]               pipe_rx3_status        ,
   output  wire                      pipe_rx3_phy_status    ,
   output  wire                      pipe_rx3_elec_idle     ,
   input   wire                      pipe_rx3_polarity      ,
   input   wire                      pipe_tx3_compliance    ,
   input   wire [ 1:0]               pipe_tx3_char_is_k     ,
   input   wire [15:0]               pipe_tx3_data          ,
   input   wire                      pipe_tx3_elec_idle     ,
   input   wire [ 1:0]               pipe_tx3_powerdown     ,

   // Pipe Per-Lane Signals - Lane 4
   output  wire [ 1:0]               pipe_rx4_char_is_k     ,
   output  wire [15:0]               pipe_rx4_data          ,
   output  wire                      pipe_rx4_valid         ,
   output  wire                      pipe_rx4_chanisaligned ,
   output  wire [ 2:0]               pipe_rx4_status        ,
   output  wire                      pipe_rx4_phy_status    ,
   output  wire                      pipe_rx4_elec_idle     ,
   input   wire                      pipe_rx4_polarity      ,
   input   wire                      pipe_tx4_compliance    ,
   input   wire [ 1:0]               pipe_tx4_char_is_k     ,
   input   wire [15:0]               pipe_tx4_data          ,
   input   wire                      pipe_tx4_elec_idle     ,
   input   wire [ 1:0]               pipe_tx4_powerdown     ,

   // Pipe Per-Lane Signals - Lane 5
   output  wire [ 1:0]               pipe_rx5_char_is_k     ,
   output  wire [15:0]               pipe_rx5_data          ,
   output  wire                      pipe_rx5_valid         ,
   output  wire                      pipe_rx5_chanisaligned ,
   output  wire [ 2:0]               pipe_rx5_status        ,
   output  wire                      pipe_rx5_phy_status    ,
   output  wire                      pipe_rx5_elec_idle     ,
   input   wire                      pipe_rx5_polarity      ,
   input   wire                      pipe_tx5_compliance    ,
   input   wire [ 1:0]               pipe_tx5_char_is_k     ,
   input   wire [15:0]               pipe_tx5_data          ,
   input   wire                      pipe_tx5_elec_idle     ,
   input   wire [ 1:0]               pipe_tx5_powerdown     ,

   // Pipe Per-Lane Signals - Lane 6
   output  wire [ 1:0]               pipe_rx6_char_is_k     ,
   output  wire [15:0]               pipe_rx6_data          ,
   output  wire                      pipe_rx6_valid         ,
   output  wire                      pipe_rx6_chanisaligned ,
   output  wire [ 2:0]               pipe_rx6_status        ,
   output  wire                      pipe_rx6_phy_status    ,
   output  wire                      pipe_rx6_elec_idle     ,
   input   wire                      pipe_rx6_polarity      ,
   input   wire                      pipe_tx6_compliance    ,
   input   wire [ 1:0]               pipe_tx6_char_is_k     ,
   input   wire [15:0]               pipe_tx6_data          ,
   input   wire                      pipe_tx6_elec_idle     ,
   input   wire [ 1:0]               pipe_tx6_powerdown     ,

   // Pipe Per-Lane Signals - Lane 7
   output  wire [ 1:0]               pipe_rx7_char_is_k     ,
   output  wire [15:0]               pipe_rx7_data          ,
   output  wire                      pipe_rx7_valid         ,
   output  wire                      pipe_rx7_chanisaligned ,
   output  wire [ 2:0]               pipe_rx7_status        ,
   output  wire                      pipe_rx7_phy_status    ,
   output  wire                      pipe_rx7_elec_idle     ,
   input   wire                      pipe_rx7_polarity      ,
   input   wire                      pipe_tx7_compliance    ,
   input   wire [ 1:0]               pipe_tx7_char_is_k     ,
   input   wire [15:0]               pipe_tx7_data          ,
   input   wire                      pipe_tx7_elec_idle     ,
   input   wire [ 1:0]               pipe_tx7_powerdown     ,

   // PCI Express signals
   output  wire [ (NO_OF_LANES-1):0] pci_exp_txn            ,
   output  wire [ (NO_OF_LANES-1):0] pci_exp_txp            ,
   input   wire [ (NO_OF_LANES-1):0] pci_exp_rxn            ,
   input   wire [ (NO_OF_LANES-1):0] pci_exp_rxp            ,

   // Non PIPE signals
   input   wire                      sys_clk                ,
   input   wire                      sys_rst_n              ,
   input   wire                      pipe_clk               ,
   input   wire                      drp_clk                ,
   input   wire                      clock_locked           ,

   output  wire                      gt_pll_lock            ,
   input   wire [ 5:0]               pl_ltssm_state         ,
   output  reg                       phy_rdy_n              ,
   output  wire                      TxOutClk
);


  wire [  7:0]                       gt_rx_phy_status_wire    ;
  wire [  7:0]                       gt_rxchanisaligned_wire  ;
  wire [127:0]                       gt_rx_data_k_wire        ;
  wire [127:0]                       gt_rx_data_wire          ;
  wire [  7:0]                       gt_rx_elec_idle_wire     ;
  wire [ 23:0]                       gt_rx_status_wire        ;
  wire [  7:0]                       gt_rx_valid_wire         ;
  wire [  7:0]                       gt_rx_polarity           ;
  wire [ 15:0]                       gt_power_down            ;
  wire [  7:0]                       gt_tx_char_disp_mode     ;
  wire [ 15:0]                       gt_tx_data_k             ;
  wire [127:0]                       gt_tx_data               ;
  wire                               gt_tx_detect_rx_loopback ;
  wire [  7:0]                       gt_tx_elec_idle          ;
  wire [  7:0]                       gt_rx_elec_idle_reset    ;
  wire [NO_OF_LANES-1:0]             plllkdet;
  wire                               RxResetDone;

  reg                                local_pcs_reset;
  reg                                local_pcs_reset_done;
  reg  [3:0]                         cnt_local_pcs_reset;
  reg  [4:0]                         phy_rdy_pre_cnt;
  reg  [5:0]                         pl_ltssm_state_q;

  wire                               plm_in_l0 = (pl_ltssm_state_q == 6'h16);
  wire                               plm_in_rl = (pl_ltssm_state_q == 6'h1c);
  wire                               plm_in_dt = (pl_ltssm_state_q == 6'h2d);
  wire                               plm_in_rs = (pl_ltssm_state_q == 6'h1f);

gtx_wrapper_v6 #(

  .NO_OF_LANES(NO_OF_LANES),
  .REF_CLK_FREQ(REF_CLK_FREQ),
  .PL_FAST_TRAIN(PL_FAST_TRAIN)

)
gtx_v6_i (

  // TX

  .TX(pci_exp_txp[((NO_OF_LANES)-1):0]),
  .TX_(pci_exp_txn[((NO_OF_LANES)-1):0]),
  .TxData(gt_tx_data[((16*NO_OF_LANES)-1):0]),
  .TxDataK(gt_tx_data_k[((2*NO_OF_LANES)-1):0]),
  .TxElecIdle(gt_tx_elec_idle[((NO_OF_LANES)-1):0]),
  .TxCompliance(gt_tx_char_disp_mode[((NO_OF_LANES)-1):0]),

  // RX

  .RX(pci_exp_rxp[((NO_OF_LANES)-1):0]),
  .RX_(pci_exp_rxn[((NO_OF_LANES)-1):0]),
  .RxData(gt_rx_data_wire[((16*NO_OF_LANES)-1):0]),
  .RxDataK(gt_rx_data_k_wire[((2*NO_OF_LANES)-1):0]),
  .RxPolarity(gt_rx_polarity[((NO_OF_LANES)-1):0]),
  .RxValid(gt_rx_valid_wire[((NO_OF_LANES)-1):0]),
  .RxElecIdle(gt_rx_elec_idle_wire[((NO_OF_LANES)-1):0]),
  .RxStatus(gt_rx_status_wire[((3*NO_OF_LANES)-1):0]),

  // other
  .GTRefClkout(),
  .plm_in_l0(plm_in_l0),
  .plm_in_rl(plm_in_rl),
  .plm_in_dt(plm_in_dt),
  .plm_in_rs(plm_in_rs),
  .RxPLLLkDet(plllkdet),
  .ChanIsAligned(gt_rxchanisaligned_wire[((NO_OF_LANES)-1):0]),
  .TxDetectRx(gt_tx_detect_rx_loopback),
  .PhyStatus(gt_rx_phy_status_wire[((NO_OF_LANES)-1):0]),
  .TXPdownAsynch(~clock_locked),
  .PowerDown(gt_power_down[((2*NO_OF_LANES)-1):0]),
  .Rate(pipe_tx_rate),
  .Reset_n(clock_locked),
  .GTReset_n(sys_rst_n),
  .PCLK(pipe_clk),
  .REFCLK(sys_clk),
  .DRPCLK(drp_clk),
  .TxDeemph(pipe_tx_deemph),
  .TxMargin(pipe_tx_margin[2]),
  .TxSwing(pipe_tx_swing),
  .local_pcs_reset(local_pcs_reset),
  .RxResetDone(RxResetDone),
  .SyncDone(SyncDone),
  .TxOutClk(TxOutClk)
);

assign pipe_rx0_phy_status = gt_rx_phy_status_wire[0] ;
assign pipe_rx1_phy_status = (NO_OF_LANES >= 2 ) ? gt_rx_phy_status_wire[1] : 1'b0;
assign pipe_rx2_phy_status = (NO_OF_LANES >= 4 ) ? gt_rx_phy_status_wire[2] : 1'b0;
assign pipe_rx3_phy_status = (NO_OF_LANES >= 4 ) ? gt_rx_phy_status_wire[3] : 1'b0;
assign pipe_rx4_phy_status = (NO_OF_LANES >= 8 ) ? gt_rx_phy_status_wire[4] : 1'b0;
assign pipe_rx5_phy_status = (NO_OF_LANES >= 8 ) ? gt_rx_phy_status_wire[5] : 1'b0;
assign pipe_rx6_phy_status = (NO_OF_LANES >= 8 ) ? gt_rx_phy_status_wire[6] : 1'b0;
assign pipe_rx7_phy_status = (NO_OF_LANES >= 8 ) ? gt_rx_phy_status_wire[7] : 1'b0;

assign pipe_rx0_chanisaligned = gt_rxchanisaligned_wire[0];
assign pipe_rx1_chanisaligned = (NO_OF_LANES >= 2 ) ? gt_rxchanisaligned_wire[1] : 1'b0 ;
assign pipe_rx2_chanisaligned = (NO_OF_LANES >= 4 ) ? gt_rxchanisaligned_wire[2] : 1'b0 ;
assign pipe_rx3_chanisaligned = (NO_OF_LANES >= 4 ) ? gt_rxchanisaligned_wire[3] : 1'b0 ;
assign pipe_rx4_chanisaligned = (NO_OF_LANES >= 8 ) ? gt_rxchanisaligned_wire[4] : 1'b0 ;
assign pipe_rx5_chanisaligned = (NO_OF_LANES >= 8 ) ? gt_rxchanisaligned_wire[5] : 1'b0 ;
assign pipe_rx6_chanisaligned = (NO_OF_LANES >= 8 ) ? gt_rxchanisaligned_wire[6] : 1'b0 ;
assign pipe_rx7_chanisaligned = (NO_OF_LANES >= 8 ) ? gt_rxchanisaligned_wire[7] : 1'b0 ;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

assign pipe_rx0_char_is_k =  {gt_rx_data_k_wire[1], gt_rx_data_k_wire[0]};
assign pipe_rx1_char_is_k =  (NO_OF_LANES >= 2 ) ? {gt_rx_data_k_wire[3], gt_rx_data_k_wire[2]} : 2'b0 ;
assign pipe_rx2_char_is_k =  (NO_OF_LANES >= 4 ) ? {gt_rx_data_k_wire[5], gt_rx_data_k_wire[4]} : 2'b0 ;
assign pipe_rx3_char_is_k =  (NO_OF_LANES >= 4 ) ? {gt_rx_data_k_wire[7], gt_rx_data_k_wire[6]} : 2'b0 ;
assign pipe_rx4_char_is_k =  (NO_OF_LANES >= 8 ) ? {gt_rx_data_k_wire[9], gt_rx_data_k_wire[8]} : 2'b0 ;
assign pipe_rx5_char_is_k =  (NO_OF_LANES >= 8 ) ? {gt_rx_data_k_wire[11], gt_rx_data_k_wire[10]} : 2'b0 ;
assign pipe_rx6_char_is_k =  (NO_OF_LANES >= 8 ) ? {gt_rx_data_k_wire[13], gt_rx_data_k_wire[12]} : 2'b0 ;
assign pipe_rx7_char_is_k =  (NO_OF_LANES >= 8 ) ? {gt_rx_data_k_wire[15], gt_rx_data_k_wire[14]} : 2'b0 ;

assign pipe_rx0_data = {gt_rx_data_wire[ 15: 8], gt_rx_data_wire[ 7: 0]};
assign pipe_rx1_data = (NO_OF_LANES >= 2 ) ? {gt_rx_data_wire[31:24], gt_rx_data_wire[23:16]} : 16'h0 ;
assign pipe_rx2_data = (NO_OF_LANES >= 4 ) ? {gt_rx_data_wire[47:40], gt_rx_data_wire[39:32]} : 16'h0 ;
assign pipe_rx3_data = (NO_OF_LANES >= 4 ) ? {gt_rx_data_wire[63:56], gt_rx_data_wire[55:48]} : 16'h0 ;
assign pipe_rx4_data = (NO_OF_LANES >= 8 ) ? {gt_rx_data_wire[79:72], gt_rx_data_wire[71:64]} : 16'h0 ;
assign pipe_rx5_data = (NO_OF_LANES >= 8 ) ? {gt_rx_data_wire[95:88], gt_rx_data_wire[87:80]} : 16'h0 ;
assign pipe_rx6_data = (NO_OF_LANES >= 8 ) ? {gt_rx_data_wire[111:104], gt_rx_data_wire[103:96]} : 16'h0 ;
assign pipe_rx7_data = (NO_OF_LANES >= 8 ) ? {gt_rx_data_wire[127:120], gt_rx_data_wire[119:112]} : 16'h0 ;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

assign pipe_rx0_elec_idle = gt_rx_elec_idle_wire[0];
assign pipe_rx1_elec_idle = (NO_OF_LANES >= 2 ) ? gt_rx_elec_idle_wire[1] : 1'b1 ;
assign pipe_rx2_elec_idle = (NO_OF_LANES >= 4 ) ? gt_rx_elec_idle_wire[2] : 1'b1 ;
assign pipe_rx3_elec_idle = (NO_OF_LANES >= 4 ) ? gt_rx_elec_idle_wire[3] : 1'b1 ;
assign pipe_rx4_elec_idle = (NO_OF_LANES >= 8 ) ? gt_rx_elec_idle_wire[4] : 1'b1 ;
assign pipe_rx5_elec_idle = (NO_OF_LANES >= 8 ) ? gt_rx_elec_idle_wire[5] : 1'b1 ;
assign pipe_rx6_elec_idle = (NO_OF_LANES >= 8 ) ? gt_rx_elec_idle_wire[6] : 1'b1 ;
assign pipe_rx7_elec_idle = (NO_OF_LANES >= 8 ) ? gt_rx_elec_idle_wire[7] : 1'b1 ;

assign pipe_rx0_status = gt_rx_status_wire[ 2: 0];
assign pipe_rx1_status = (NO_OF_LANES >= 2 ) ? gt_rx_status_wire[ 5: 3] : 3'b0 ;
assign pipe_rx2_status = (NO_OF_LANES >= 4 ) ? gt_rx_status_wire[ 8: 6] : 3'b0 ;
assign pipe_rx3_status = (NO_OF_LANES >= 4 ) ? gt_rx_status_wire[11: 9] : 3'b0 ;
assign pipe_rx4_status = (NO_OF_LANES >= 8 ) ? gt_rx_status_wire[14:12] : 3'b0 ;
assign pipe_rx5_status = (NO_OF_LANES >= 8 ) ? gt_rx_status_wire[17:15] : 3'b0 ;
assign pipe_rx6_status = (NO_OF_LANES >= 8 ) ? gt_rx_status_wire[20:18] : 3'b0 ;
assign pipe_rx7_status = (NO_OF_LANES >= 8 ) ? gt_rx_status_wire[23:21] : 3'b0 ;

assign pipe_rx0_valid = gt_rx_valid_wire[0];
assign pipe_rx1_valid = (NO_OF_LANES >= 2 ) ? gt_rx_valid_wire[1] : 1'b0 ;
assign pipe_rx2_valid = (NO_OF_LANES >= 4 ) ? gt_rx_valid_wire[2] : 1'b0 ;
assign pipe_rx3_valid = (NO_OF_LANES >= 4 ) ? gt_rx_valid_wire[3] : 1'b0 ;
assign pipe_rx4_valid = (NO_OF_LANES >= 8 ) ? gt_rx_valid_wire[4] : 1'b0 ;
assign pipe_rx5_valid = (NO_OF_LANES >= 8 ) ? gt_rx_valid_wire[5] : 1'b0 ;
assign pipe_rx6_valid = (NO_OF_LANES >= 8 ) ? gt_rx_valid_wire[6] : 1'b0 ;
assign pipe_rx7_valid = (NO_OF_LANES >= 8 ) ? gt_rx_valid_wire[7] : 1'b0 ;

assign gt_rx_polarity[0] = pipe_rx0_polarity;
assign gt_rx_polarity[1] = pipe_rx1_polarity;
assign gt_rx_polarity[2] = pipe_rx2_polarity;
assign gt_rx_polarity[3] = pipe_rx3_polarity;
assign gt_rx_polarity[4] = pipe_rx4_polarity;
assign gt_rx_polarity[5] = pipe_rx5_polarity;
assign gt_rx_polarity[6] = pipe_rx6_polarity;
assign gt_rx_polarity[7] = pipe_rx7_polarity;

assign gt_power_down[ 1: 0] = pipe_tx0_powerdown;
assign gt_power_down[ 3: 2] = pipe_tx1_powerdown;
assign gt_power_down[ 5: 4] = pipe_tx2_powerdown;
assign gt_power_down[ 7: 6] = pipe_tx3_powerdown;
assign gt_power_down[ 9: 8] = pipe_tx4_powerdown;
assign gt_power_down[11:10] = pipe_tx5_powerdown;
assign gt_power_down[13:12] = pipe_tx6_powerdown;
assign gt_power_down[15:14] = pipe_tx7_powerdown;

assign gt_tx_char_disp_mode = {pipe_tx7_compliance,
                               pipe_tx6_compliance,
                               pipe_tx5_compliance,
                               pipe_tx4_compliance,
                               pipe_tx3_compliance,
                               pipe_tx2_compliance,
                               pipe_tx1_compliance,
                               pipe_tx0_compliance};


assign gt_tx_data_k = {pipe_tx7_char_is_k,
                       pipe_tx6_char_is_k,
                       pipe_tx5_char_is_k,
                       pipe_tx4_char_is_k,
                       pipe_tx3_char_is_k,
                       pipe_tx2_char_is_k,
                       pipe_tx1_char_is_k,
                       pipe_tx0_char_is_k};

assign gt_tx_data = {pipe_tx7_data,
                     pipe_tx6_data,
                     pipe_tx5_data,
                     pipe_tx4_data,
                     pipe_tx3_data,
                     pipe_tx2_data,
                     pipe_tx1_data,
                     pipe_tx0_data};

assign gt_tx_detect_rx_loopback = pipe_tx_rcvr_det;

assign gt_tx_elec_idle = {pipe_tx7_elec_idle,
                          pipe_tx6_elec_idle,
                          pipe_tx5_elec_idle,
                          pipe_tx4_elec_idle,
                          pipe_tx3_elec_idle,
                          pipe_tx2_elec_idle,
                          pipe_tx1_elec_idle,
                          pipe_tx0_elec_idle};

assign gt_pll_lock = &plllkdet[NO_OF_LANES-1:0] | ~phy_rdy_pre_cnt[4];

// Asserted after all workarounds have completed.

always @(posedge pipe_clk or negedge clock_locked) begin

  if (!clock_locked) begin

    phy_rdy_n <= #TCQ 1'b1;

  end else begin

    if (~&plllkdet[NO_OF_LANES-1:0])
      phy_rdy_n <= #TCQ 1'b1;
    else if (local_pcs_reset_done && RxResetDone && phy_rdy_n &&  SyncDone)
      phy_rdy_n <= #TCQ 1'b0;

  end

end

// Handle the warm reset case, where sys_rst_n is asseted when
// phy_rdy_n is asserted. phy_rdy_n is to be de-asserted
// before gt_pll_lock is de-asserted so that synnchronous
// logic see reset de-asset before clock is lost.

always @(posedge pipe_clk or negedge clock_locked) begin

  if (!clock_locked) begin

    phy_rdy_pre_cnt <= #TCQ 5'b11111;

  end else begin

    if (gt_pll_lock && phy_rdy_n)
      phy_rdy_pre_cnt <= #TCQ phy_rdy_pre_cnt + 1'b1;

  end

end

always @(posedge pipe_clk or negedge clock_locked) begin

  if (!clock_locked) begin

    cnt_local_pcs_reset <= #TCQ 4'hF;
    local_pcs_reset <= #TCQ 1'b0;
    local_pcs_reset_done <= #TCQ 1'b0;

  end else begin

    if ((local_pcs_reset == 1'b0) && (cnt_local_pcs_reset == 4'hF))
      local_pcs_reset <= #TCQ 1'b1;
    else if ((local_pcs_reset == 1'b1) && (cnt_local_pcs_reset != 4'h0)) begin
      local_pcs_reset <= #TCQ 1'b1;
      cnt_local_pcs_reset <= #TCQ cnt_local_pcs_reset - 1'b1;
    end else if ((local_pcs_reset == 1'b1) && (cnt_local_pcs_reset == 4'h0)) begin
      local_pcs_reset <= #TCQ 1'b0;
      local_pcs_reset_done <= #TCQ 1'b1;
    end

  end

end

always @(posedge pipe_clk or negedge clock_locked) begin

  if (!clock_locked)
    pl_ltssm_state_q <= #TCQ 6'b0;
  else
    pl_ltssm_state_q <= #TCQ pl_ltssm_state;

end

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

endmodule
