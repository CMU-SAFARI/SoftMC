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
// File       : pcie_endpoint.v
// Version    : 2.4
//--
//-- Description: Virtex6 solution wrapper : Endpoint for PCI Express
//--
//--
//--
//--------------------------------------------------------------------------------

`timescale 1ns/1ns

(* CORE_GENERATION_INFO = "pcie_endpoint,v6_pcie_v2_5,{LINK_CAP_MAX_LINK_SPEED=1,LINK_CAP_MAX_LINK_WIDTH=08,PCIE_CAP_DEVICE_PORT_TYPE=0000,DEV_CAP_MAX_PAYLOAD_SUPPORTED=2,USER_CLK_FREQ=3,REF_CLK_FREQ=2,MSI_CAP_ON=TRUE,MSI_CAP_MULTIMSGCAP=0,MSI_CAP_MULTIMSG_EXTENSION=0,MSIX_CAP_ON=FALSE,TL_TX_RAM_RADDR_LATENCY=0,TL_TX_RAM_RDATA_LATENCY=2,TL_RX_RAM_RADDR_LATENCY=0,TL_RX_RAM_RDATA_LATENCY=2,TL_RX_RAM_WRITE_LATENCY=0,VC0_TX_LASTPACKET=29,VC0_RX_RAM_LIMIT=7FF,VC0_TOTAL_CREDITS_PH=4,VC0_TOTAL_CREDITS_PD=64,VC0_TOTAL_CREDITS_NPH=4,VC0_TOTAL_CREDITS_CH=72,VC0_TOTAL_CREDITS_CD=850,VC0_CPL_INFINITE=TRUE,DEV_CAP_PHANTOM_FUNCTIONS_SUPPORT=0,DEV_CAP_EXT_TAG_SUPPORTED=FALSE,LINK_STATUS_SLOT_CLOCK_CONFIG=FALSE,ENABLE_RX_TD_ECRC_TRIM=FALSE,DISABLE_LANE_REVERSAL=TRUE,DISABLE_SCRAMBLING=FALSE,DSN_CAP_ON=TRUE,PIPE_PIPELINE_STAGES=0,REVISION_ID=00,VC_CAP_ON=FALSE}" *)
module pcie_endpoint # (
  parameter        ALLOW_X8_GEN2 = "FALSE",
  parameter        BAR0 = 32'hFFFFFC00,
  parameter        BAR1 = 32'h00000000,
  parameter        BAR2 = 32'h00000000,
  parameter        BAR3 = 32'h00000000,
  parameter        BAR4 = 32'h00000000,
  parameter        BAR5 = 32'h00000000,

  parameter        CARDBUS_CIS_POINTER = 32'h00000000,
  parameter        CLASS_CODE = 24'h050000,
  parameter        CMD_INTX_IMPLEMENTED = "TRUE",
  parameter        CPL_TIMEOUT_DISABLE_SUPPORTED = "FALSE",
  parameter        CPL_TIMEOUT_RANGES_SUPPORTED = 4'h2,

  parameter        DEV_CAP_ENDPOINT_L0S_LATENCY = 0,
  parameter        DEV_CAP_ENDPOINT_L1_LATENCY = 7,
  parameter        DEV_CAP_EXT_TAG_SUPPORTED = "FALSE",
  parameter        DEV_CAP_MAX_PAYLOAD_SUPPORTED = 2,
  parameter        DEV_CAP_PHANTOM_FUNCTIONS_SUPPORT = 0,
  parameter        DEVICE_ID = 16'h6018,

  parameter        DISABLE_LANE_REVERSAL = "TRUE",
  parameter        DISABLE_SCRAMBLING = "FALSE",
  parameter        DSN_BASE_PTR = 12'h100,
  parameter        DSN_CAP_NEXTPTR = 12'h000,
  parameter        DSN_CAP_ON = "TRUE",

  parameter        ENABLE_MSG_ROUTE = 11'b00000000000,
  parameter        ENABLE_RX_TD_ECRC_TRIM = "FALSE",
  parameter        EXPANSION_ROM = 32'h00000000,
  parameter        EXT_CFG_CAP_PTR = 6'h3F,
  parameter        EXT_CFG_XP_CAP_PTR = 10'h3FF,
  parameter        HEADER_TYPE = 8'h00,
  parameter        INTERRUPT_PIN = 8'h1,

  parameter        LINK_CAP_DLL_LINK_ACTIVE_REPORTING_CAP = "FALSE",
  parameter        LINK_CAP_LINK_BANDWIDTH_NOTIFICATION_CAP = "FALSE",
  parameter        LINK_CAP_MAX_LINK_SPEED = 4'h1,
  parameter        LINK_CAP_MAX_LINK_WIDTH = 6'h08,
  parameter        LINK_CAP_SURPRISE_DOWN_ERROR_CAPABLE = "FALSE",

  parameter        LINK_CTRL2_DEEMPHASIS = "FALSE",
  parameter        LINK_CTRL2_HW_AUTONOMOUS_SPEED_DISABLE = "FALSE",
  parameter        LINK_CTRL2_TARGET_LINK_SPEED = 4'h0,
  parameter        LINK_STATUS_SLOT_CLOCK_CONFIG = "FALSE",

  parameter        LL_ACK_TIMEOUT = 15'h0000,
  parameter        LL_ACK_TIMEOUT_EN = "FALSE",
  parameter        LL_ACK_TIMEOUT_FUNC = 0,
  parameter        LL_REPLAY_TIMEOUT = 15'h0026,
  parameter        LL_REPLAY_TIMEOUT_EN = "TRUE",
  parameter        LL_REPLAY_TIMEOUT_FUNC = 1,

  parameter        LTSSM_MAX_LINK_WIDTH = 6'h08,
  parameter        MSI_CAP_MULTIMSGCAP = 0,
  parameter        MSI_CAP_MULTIMSG_EXTENSION = 0,
  parameter        MSI_CAP_ON = "TRUE",
  parameter        MSI_CAP_PER_VECTOR_MASKING_CAPABLE = "FALSE",
  parameter        MSI_CAP_64_BIT_ADDR_CAPABLE = "TRUE",

  parameter        MSIX_CAP_ON = "FALSE",
  parameter        MSIX_CAP_PBA_BIR = 0,
  parameter        MSIX_CAP_PBA_OFFSET = 29'h0,
  parameter        MSIX_CAP_TABLE_BIR = 0,
  parameter        MSIX_CAP_TABLE_OFFSET = 29'h0,
  parameter        MSIX_CAP_TABLE_SIZE = 11'h0,

  parameter        PCIE_CAP_DEVICE_PORT_TYPE = 4'b0000,
  parameter        PCIE_CAP_INT_MSG_NUM = 5'h1,
  parameter        PCIE_CAP_NEXTPTR = 8'h00,
  parameter        PCIE_DRP_ENABLE = "FALSE",
  parameter        PIPE_PIPELINE_STAGES = 0,                // 0 - 0 stages, 1 - 1 stage, 2 - 2 stages

  parameter        PM_CAP_DSI = "FALSE",
  parameter        PM_CAP_D1SUPPORT = "FALSE",
  parameter        PM_CAP_D2SUPPORT = "FALSE",
  parameter        PM_CAP_NEXTPTR = 8'h48,
  parameter        PM_CAP_PMESUPPORT = 5'h0F,
  parameter        PM_CSR_NOSOFTRST = "TRUE",

  parameter        PM_DATA_SCALE0 = 2'h0,
  parameter        PM_DATA_SCALE1 = 2'h0,
  parameter        PM_DATA_SCALE2 = 2'h0,
  parameter        PM_DATA_SCALE3 = 2'h0,
  parameter        PM_DATA_SCALE4 = 2'h0,
  parameter        PM_DATA_SCALE5 = 2'h0,
  parameter        PM_DATA_SCALE6 = 2'h0,
  parameter        PM_DATA_SCALE7 = 2'h0,

  parameter        PM_DATA0 = 8'h00,
  parameter        PM_DATA1 = 8'h00,
  parameter        PM_DATA2 = 8'h00,
  parameter        PM_DATA3 = 8'h00,
  parameter        PM_DATA4 = 8'h00,
  parameter        PM_DATA5 = 8'h00,
  parameter        PM_DATA6 = 8'h00,
  parameter        PM_DATA7 = 8'h00,

  parameter        REF_CLK_FREQ = 2,                        // 0 - 100 MHz, 1 - 125 MHz, 2 - 250 MHz
  parameter        REVISION_ID = 8'h00,
  parameter        SPARE_BIT0 = 0,
  parameter        SUBSYSTEM_ID = 16'h0007,
  parameter        SUBSYSTEM_VENDOR_ID = 16'h10EE,

  parameter        TL_RX_RAM_RADDR_LATENCY = 0,
  parameter        TL_RX_RAM_RDATA_LATENCY = 2,
  parameter        TL_RX_RAM_WRITE_LATENCY = 0,
  parameter        TL_TX_RAM_RADDR_LATENCY = 0,
  parameter        TL_TX_RAM_RDATA_LATENCY = 2,
  parameter        TL_TX_RAM_WRITE_LATENCY = 0,

  parameter        UPCONFIG_CAPABLE = "TRUE",
  parameter        USER_CLK_FREQ = 3,
  parameter        VC_BASE_PTR = 12'h0,
  parameter        VC_CAP_NEXTPTR = 12'h000,
  parameter        VC_CAP_ON = "FALSE",
  parameter        VC_CAP_REJECT_SNOOP_TRANSACTIONS = "FALSE",

  parameter        VC0_CPL_INFINITE = "TRUE",
  parameter        VC0_RX_RAM_LIMIT = 13'h7FF,
  parameter        VC0_TOTAL_CREDITS_CD = 850,
  parameter        VC0_TOTAL_CREDITS_CH = 72,
  parameter        VC0_TOTAL_CREDITS_NPH = 4,
  parameter        VC0_TOTAL_CREDITS_PD = 64,
  parameter        VC0_TOTAL_CREDITS_PH = 4,
  parameter        VC0_TX_LASTPACKET = 29,

  parameter        VENDOR_ID = 16'h10EE,
  parameter        VSEC_BASE_PTR = 12'h0,
  parameter        VSEC_CAP_NEXTPTR = 12'h000,
  parameter        VSEC_CAP_ON = "FALSE",

  parameter        AER_BASE_PTR = 12'h128,
  parameter        AER_CAP_ECRC_CHECK_CAPABLE = "FALSE",
  parameter        AER_CAP_ECRC_GEN_CAPABLE = "FALSE",
  parameter        AER_CAP_ID = 16'h0001,
  parameter        AER_CAP_INT_MSG_NUM_MSI = 5'h0a,
  parameter        AER_CAP_INT_MSG_NUM_MSIX = 5'h15,
  parameter        AER_CAP_NEXTPTR = 12'h160,
  parameter        AER_CAP_ON = "FALSE",
  parameter        AER_CAP_PERMIT_ROOTERR_UPDATE = "TRUE",
  parameter        AER_CAP_VERSION = 4'h1,

  parameter        CAPABILITIES_PTR = 8'h40,
  parameter        CRM_MODULE_RSTS = 7'h00,
  parameter        DEV_CAP_ENABLE_SLOT_PWR_LIMIT_SCALE = "TRUE",
  parameter        DEV_CAP_ENABLE_SLOT_PWR_LIMIT_VALUE = "TRUE",
  parameter        DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE = "FALSE",
  parameter        DEV_CAP_ROLE_BASED_ERROR = "TRUE",
  parameter        DEV_CAP_RSVD_14_12 = 0,
  parameter        DEV_CAP_RSVD_17_16 = 0,
  parameter        DEV_CAP_RSVD_31_29 = 0,
  parameter        DEV_CONTROL_AUX_POWER_SUPPORTED = "FALSE",

  parameter        DISABLE_ASPM_L1_TIMER = "FALSE",
  parameter        DISABLE_BAR_FILTERING = "FALSE",
  parameter        DISABLE_ID_CHECK = "FALSE",
  parameter        DISABLE_RX_TC_FILTER = "FALSE",
  parameter        DNSTREAM_LINK_NUM = 8'h00,

  parameter        DSN_CAP_ID = 16'h0003,
  parameter        DSN_CAP_VERSION = 4'h1,
  parameter        ENTER_RVRY_EI_L0 = "TRUE",
  parameter        INFER_EI = 5'h0c,
  parameter        IS_SWITCH = "FALSE",

  parameter        LAST_CONFIG_DWORD = 10'h3FF,
  parameter        LINK_CAP_ASPM_SUPPORT = 1,
  parameter        LINK_CAP_CLOCK_POWER_MANAGEMENT = "FALSE",
  parameter        LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN1 = 7,
  parameter        LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN2 = 7,
  parameter        LINK_CAP_L0S_EXIT_LATENCY_GEN1 = 7,
  parameter        LINK_CAP_L0S_EXIT_LATENCY_GEN2 = 7,
  parameter        LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN1 = 7,
  parameter        LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN2 = 7,
  parameter        LINK_CAP_L1_EXIT_LATENCY_GEN1 = 7,
  parameter        LINK_CAP_L1_EXIT_LATENCY_GEN2 = 7,
  parameter        LINK_CAP_RSVD_23_22 = 0,
  parameter        LINK_CONTROL_RCB = 0,

  parameter        MSI_BASE_PTR = 8'h48,
  parameter        MSI_CAP_ID = 8'h05,
  parameter        MSI_CAP_NEXTPTR = 8'h60,
  parameter        MSIX_BASE_PTR = 8'h9c,
  parameter        MSIX_CAP_ID = 8'h11,
  parameter        MSIX_CAP_NEXTPTR = 8'h00,
  parameter        N_FTS_COMCLK_GEN1 = 255,
  parameter        N_FTS_COMCLK_GEN2 = 254,
  parameter        N_FTS_GEN1 = 255,
  parameter        N_FTS_GEN2 = 255,

  parameter        PCIE_BASE_PTR = 8'h60,
  parameter        PCIE_CAP_CAPABILITY_ID = 8'h10,
  parameter        PCIE_CAP_CAPABILITY_VERSION = 4'h2,
  parameter        PCIE_CAP_ON = "TRUE",
  parameter        PCIE_CAP_RSVD_15_14 = 0,
  parameter        PCIE_CAP_SLOT_IMPLEMENTED = "FALSE",
  parameter        PCIE_REVISION = 2,
  parameter        PGL0_LANE = 0,
  parameter        PGL1_LANE = 1,
  parameter        PGL2_LANE = 2,
  parameter        PGL3_LANE = 3,
  parameter        PGL4_LANE = 4,
  parameter        PGL5_LANE = 5,
  parameter        PGL6_LANE = 6,
  parameter        PGL7_LANE = 7,
  parameter        PL_AUTO_CONFIG = 0,
  parameter        PL_FAST_TRAIN = "FALSE",

  parameter        PM_BASE_PTR = 8'h40,
  parameter        PM_CAP_AUXCURRENT = 0,
  parameter        PM_CAP_ID = 8'h01,
  parameter        PM_CAP_ON = "TRUE",
  parameter        PM_CAP_PME_CLOCK = "FALSE",
  parameter        PM_CAP_RSVD_04 = 0,
  parameter        PM_CAP_VERSION = 3,
  parameter        PM_CSR_BPCCEN = "FALSE",
  parameter        PM_CSR_B2B3 = "FALSE",

  parameter        RECRC_CHK = 0,
  parameter        RECRC_CHK_TRIM = "FALSE",
  parameter        ROOT_CAP_CRS_SW_VISIBILITY = "FALSE",
  parameter        SELECT_DLL_IF = "FALSE",
  parameter        SLOT_CAP_ATT_BUTTON_PRESENT = "FALSE",
  parameter        SLOT_CAP_ATT_INDICATOR_PRESENT = "FALSE",
  parameter        SLOT_CAP_ELEC_INTERLOCK_PRESENT = "FALSE",
  parameter        SLOT_CAP_HOTPLUG_CAPABLE = "FALSE",
  parameter        SLOT_CAP_HOTPLUG_SURPRISE = "FALSE",
  parameter        SLOT_CAP_MRL_SENSOR_PRESENT = "FALSE",
  parameter        SLOT_CAP_NO_CMD_COMPLETED_SUPPORT = "FALSE",
  parameter        SLOT_CAP_PHYSICAL_SLOT_NUM = 13'h0000,
  parameter        SLOT_CAP_POWER_CONTROLLER_PRESENT = "FALSE",
  parameter        SLOT_CAP_POWER_INDICATOR_PRESENT = "FALSE",
  parameter        SLOT_CAP_SLOT_POWER_LIMIT_SCALE = 0,
  parameter        SLOT_CAP_SLOT_POWER_LIMIT_VALUE = 8'h00,
  parameter        SPARE_BIT1 = 0,
  parameter        SPARE_BIT2 = 0,
  parameter        SPARE_BIT3 = 0,
  parameter        SPARE_BIT4 = 0,
  parameter        SPARE_BIT5 = 0,
  parameter        SPARE_BIT6 = 0,
  parameter        SPARE_BIT7 = 0,
  parameter        SPARE_BIT8 = 0,
  parameter        SPARE_BYTE0 = 8'h00,
  parameter        SPARE_BYTE1 = 8'h00,
  parameter        SPARE_BYTE2 = 8'h00,
  parameter        SPARE_BYTE3 = 8'h00,
  parameter        SPARE_WORD0 = 32'h00000000,
  parameter        SPARE_WORD1 = 32'h00000000,
  parameter        SPARE_WORD2 = 32'h00000000,
  parameter        SPARE_WORD3 = 32'h00000000,

  parameter        TL_RBYPASS = "FALSE",
  parameter        TL_TFC_DISABLE = "FALSE",
  parameter        TL_TX_CHECKS_DISABLE = "FALSE",
  parameter        EXIT_LOOPBACK_ON_EI  = "TRUE",
  parameter        UPSTREAM_FACING = "TRUE",
  parameter        UR_INV_REQ = "TRUE",

  parameter        VC_CAP_ID = 16'h0002,
  parameter        VC_CAP_VERSION = 4'h1,
  parameter        VSEC_CAP_HDR_ID = 16'h1234,
  parameter        VSEC_CAP_HDR_LENGTH = 12'h018,
  parameter        VSEC_CAP_HDR_REVISION = 4'h1,
  parameter        VSEC_CAP_ID = 16'h000b,
  parameter        VSEC_CAP_IS_LINK_VISIBLE = "TRUE",
  parameter        VSEC_CAP_VERSION = 4'h1
)
(
  //-------------------------------------------------------
  // 1. PCI Express (pci_exp) Interface
  //-------------------------------------------------------

  // Tx
  output  [(LINK_CAP_MAX_LINK_WIDTH - 1):0]     pci_exp_txp,
  output  [(LINK_CAP_MAX_LINK_WIDTH - 1):0]     pci_exp_txn,

  // Rx
  input   [(LINK_CAP_MAX_LINK_WIDTH - 1):0]     pci_exp_rxp,
  input   [(LINK_CAP_MAX_LINK_WIDTH - 1):0]     pci_exp_rxn,

  //-------------------------------------------------------
  // 2. AXI-S Interface
  //-------------------------------------------------------

  // Common
  output                                        user_clk_out,
  output                                        user_reset_out,
  output                                        user_lnk_up,

  // Tx
  output  [5:0]                                 tx_buf_av,
  output                                        tx_err_drop,
  output                                        tx_cfg_req,
  output                                        s_axis_tx_tready,
  input  [63:0]                                 s_axis_tx_tdata,
  input  [7:0]                                  s_axis_tx_tkeep,
  input  [3:0]                                  s_axis_tx_tuser,
  input                                         s_axis_tx_tlast,
  input                                         s_axis_tx_tvalid,
  input                                         tx_cfg_gnt,

  // Rx
  output  [63:0]                                m_axis_rx_tdata,
  output  [7:0]                                 m_axis_rx_tkeep,
  output                                        m_axis_rx_tlast,
  output                                        m_axis_rx_tvalid,
  input                                         m_axis_rx_tready,
  output    [21:0]                              m_axis_rx_tuser,
  input                                         rx_np_ok,

  // Flow Control
  output [11:0]                                 fc_cpld,
  output  [7:0]                                 fc_cplh,
  output [11:0]                                 fc_npd,
  output  [7:0]                                 fc_nph,
  output [11:0]                                 fc_pd,
  output  [7:0]                                 fc_ph,
  input   [2:0]                                 fc_sel,


  //-------------------------------------------------------
  // 3. Configuration (CFG) Interface
  //-------------------------------------------------------

  output [31:0]                                 cfg_do,
  output                                        cfg_rd_wr_done,
  input  [31:0]                                 cfg_di,
  input   [3:0]                                 cfg_byte_en,
  input   [9:0]                                 cfg_dwaddr,
  input                                         cfg_wr_en,
  input                                         cfg_rd_en,

  input                                         cfg_err_cor,
  input                                         cfg_err_ur,
  input                                         cfg_err_ecrc,
  input                                         cfg_err_cpl_timeout,
  input                                         cfg_err_cpl_abort,
  input                                         cfg_err_cpl_unexpect,
  input                                         cfg_err_posted,
  input                                         cfg_err_locked,
  input  [47:0]                                 cfg_err_tlp_cpl_header,
  output                                        cfg_err_cpl_rdy,
  input                                         cfg_interrupt,
  output                                        cfg_interrupt_rdy,
  input                                         cfg_interrupt_assert,
  input  [7:0]                                  cfg_interrupt_di,
  output [7:0]                                  cfg_interrupt_do,
  output [2:0]                                  cfg_interrupt_mmenable,
  output                                        cfg_interrupt_msienable,
  output                                        cfg_interrupt_msixenable,
  output                                        cfg_interrupt_msixfm,
  input                                         cfg_turnoff_ok,
  output                                        cfg_to_turnoff,
  input                                         cfg_trn_pending,
  input                                         cfg_pm_wake,
  output  [7:0]                                 cfg_bus_number,
  output  [4:0]                                 cfg_device_number,
  output  [2:0]                                 cfg_function_number,
  output [15:0]                                 cfg_status,
  output [15:0]                                 cfg_command,
  output [15:0]                                 cfg_dstatus,
  output [15:0]                                 cfg_dcommand,
  output [15:0]                                 cfg_lstatus,
  output [15:0]                                 cfg_lcommand,
  output [15:0]                                 cfg_dcommand2,
  output  [2:0]                                 cfg_pcie_link_state,
  input  [63:0]                                 cfg_dsn,
  output                                        cfg_pmcsr_pme_en,
  output                                        cfg_pmcsr_pme_status,
  output  [1:0]                                 cfg_pmcsr_powerstate,

  //-------------------------------------------------------
  // 4. Physical Layer Control and Status (PL) Interface
  //-------------------------------------------------------

  output [2:0]                                  pl_initial_link_width,
  output [1:0]                                  pl_lane_reversal_mode,
  output                                        pl_link_gen2_capable,
  output                                        pl_link_partner_gen2_supported,
  output                                        pl_link_upcfg_capable,
  output [5:0]                                  pl_ltssm_state,
  output                                        pl_received_hot_rst,
  output                                        pl_sel_link_rate,
  output [1:0]                                  pl_sel_link_width,
  input                                         pl_directed_link_auton,
  input  [1:0]                                  pl_directed_link_change,
  input                                         pl_directed_link_speed,
  input  [1:0]                                  pl_directed_link_width,
  input                                         pl_upstream_prefer_deemph,

  //-------------------------------------------------------
  // 5. System  (SYS) Interface
  //-------------------------------------------------------

  input                                         sys_clk,
  input                                         sys_reset


);


  wire  [63:0]                                  trn_td;
  wire                                          trn_trem;
  wire                                          trn_tsof;
  wire                                          trn_teof;
  wire                                          trn_tsrc_rdy;
  wire                                          trn_tdst_rdy_n;
  wire                                          trn_terr_drop_n;
  wire                                          trn_tsrc_dsc;
  wire                                          trn_terrfwd;
  wire                                          trn_tstr;
  wire                                          trn_tecrc_gen;

  wire  [63:0]                                  trn_rd;
  wire                                          trn_rrem_n;
  wire                                          trn_rsof_n;
  wire                                          trn_reof_n;
  wire                                          trn_rsrc_rdy_n;
  wire                                          trn_rdst_rdy;
  wire                                          trn_rsrc_dsc_n;
  wire                                          trn_rerrfwd_n;
  wire  [6:0]                                   trn_rbar_hit_n;

  wire                                          trn_tcfg_gnt;

  wire  [31:0]                                  trn_rdllp_data;
  wire                                          trn_rdllp_src_rdy_n;


  wire                                          rx_func_level_reset_n;
  wire                                          cfg_msg_received;
  wire                                          cfg_msg_received_pme_to;

  wire                                          cfg_cmd_bme;
  wire                                          cfg_cmd_intdis;
  wire                                          cfg_cmd_io_en;
  wire                                          cfg_cmd_mem_en;
  wire                                          cfg_cmd_serr_en;
  wire                                          cfg_dev_control_aux_power_en ;
  wire                                          cfg_dev_control_corr_err_reporting_en ;
  wire                                          cfg_dev_control_enable_relaxed_order ;
  wire                                          cfg_dev_control_ext_tag_en ;
  wire                                          cfg_dev_control_fatal_err_reporting_en ;
  wire [2:0]                                    cfg_dev_control_maxpayload ;
  wire [2:0]                                    cfg_dev_control_max_read_req ;
  wire                                          cfg_dev_control_non_fatal_reporting_en ;
  wire                                          cfg_dev_control_nosnoop_en ;
  wire                                          cfg_dev_control_phantom_en ;
  wire                                          cfg_dev_control_ur_err_reporting_en ;
  wire                                          cfg_dev_control2_cpltimeout_dis ;
  wire [3:0]                                    cfg_dev_control2_cpltimeout_val ;
  wire                                          cfg_dev_status_corr_err_detected ;
  wire                                          cfg_dev_status_fatal_err_detected ;
  wire                                          cfg_dev_status_nonfatal_err_detected ;
  wire                                          cfg_dev_status_ur_detected ;
  wire                                          cfg_link_control_auto_bandwidth_int_en ;
  wire                                          cfg_link_control_bandwidth_int_en ;
  wire                                          cfg_link_control_hw_auto_width_dis ;
  wire                                          cfg_link_control_clock_pm_en ;
  wire                                          cfg_link_control_extended_sync ;
  wire                                          cfg_link_control_common_clock ;
  wire                                          cfg_link_control_retrain_link ;
  wire                                          cfg_link_control_linkdisable ;
  wire                                          cfg_link_control_rcb ;
  wire [1:0]                                    cfg_link_control_aspm_control ;
  wire                                          cfg_link_status_autobandwidth_status ;
  wire                                          cfg_link_status_bandwidth_status ;
  wire                                          cfg_link_status_dll_active ;
  wire                                          cfg_link_status_link_training ;
  wire [3:0]                                    cfg_link_status_negotiated_link_width ;
  wire [1:0]                                    cfg_link_status_current_speed ;
  wire [15:0]                                   cfg_msg_data;

  wire                                          sys_reset_n_d;
  wire                                          phy_rdy_n;

  wire                                          trn_lnk_up_n_int;
  wire                                          trn_lnk_up_n_int1;

  wire                                          trn_reset_n_int;
  wire                                          trn_reset_n_int1;

  wire                                          TxOutClk;
  wire                                          TxOutClk_bufg;

  reg  [7:0]                                    cfg_bus_number_d;
  reg  [4:0]                                    cfg_device_number_d;
  reg  [2:0]                                    cfg_function_number_d;

  wire                                          cfg_rd_wr_done_n;
  wire                                          cfg_interrupt_rdy_n;
  wire                                          cfg_turnoff_ok_w;
  wire                                          trn_recrc_err_n;
  wire                                          cfg_err_cpl_rdy_n;
  wire                                          trn_tcfg_req_n;


  // Inversion logic
  assign      cfg_rd_wr_done          = !cfg_rd_wr_done_n ;
  wire [3:0]  cfg_byte_en_n           = ~cfg_byte_en ;
  wire        cfg_wr_en_n             = !cfg_wr_en ;
  wire        cfg_rd_en_n             = !cfg_rd_en ;
  wire        cfg_trn_pending_n       = !cfg_trn_pending ;
  wire        cfg_turnoff_ok_n        = !cfg_turnoff_ok_w ;
  wire        cfg_pm_wake_n           = !cfg_pm_wake ;
  wire        cfg_interrupt_n         = !cfg_interrupt ;
  assign      cfg_interrupt_rdy       = !cfg_interrupt_rdy_n ;
  wire        cfg_interrupt_assert_n  = !cfg_interrupt_assert ;
  wire        cfg_err_ecrc_n          = !cfg_err_ecrc ;
  wire        cfg_err_ur_n            = !cfg_err_ur ;
  wire        cfg_err_cpl_timeout_n   = !cfg_err_cpl_timeout ;
  wire        cfg_err_cpl_unexpect_n  = !cfg_err_cpl_unexpect ;
  wire        cfg_err_cpl_abort_n     = !cfg_err_cpl_abort ;
  wire        cfg_err_posted_n        = !cfg_err_posted ;
  wire        cfg_err_cor_n           = !cfg_err_cor ;
  assign      cfg_err_cpl_rdy         = !cfg_err_cpl_rdy_n ;
  wire        cfg_err_locked_n        = !cfg_err_locked ;
  wire        trn_recrc_err           = !trn_recrc_err_n;
  assign      tx_err_drop             = !trn_terr_drop_n;
  assign      tx_cfg_req              = !trn_tcfg_req_n;



  // assigns to outputs

  assign                                        cfg_to_turnoff = cfg_msg_received_pme_to;

  assign                                        cfg_status = {16'b0};

  assign                                        cfg_command = {5'b0,
                                                               cfg_cmd_intdis,
                                                               1'b0,
                                                               cfg_cmd_serr_en,
                                                               5'b0,
                                                               cfg_cmd_bme,
                                                               cfg_cmd_mem_en,
                                                               cfg_cmd_io_en};

  assign                                        cfg_dstatus = {10'h0,
                                                               cfg_trn_pending,
                                                               1'b0,
                                                               cfg_dev_status_ur_detected,
                                                               cfg_dev_status_fatal_err_detected,
                                                               cfg_dev_status_nonfatal_err_detected,
                                                               cfg_dev_status_corr_err_detected};

  assign                                        cfg_dcommand = {1'b0,
                                                               cfg_dev_control_max_read_req,
                                                               cfg_dev_control_nosnoop_en,
                                                               cfg_dev_control_aux_power_en,
                                                               cfg_dev_control_phantom_en,
                                                               cfg_dev_control_ext_tag_en,
                                                               cfg_dev_control_maxpayload,
                                                               cfg_dev_control_enable_relaxed_order,
                                                               cfg_dev_control_ur_err_reporting_en,
                                                               cfg_dev_control_fatal_err_reporting_en,
                                                               cfg_dev_control_non_fatal_reporting_en,
                                                               cfg_dev_control_corr_err_reporting_en };

  assign                                        cfg_lstatus = {cfg_link_status_autobandwidth_status,
                                                               cfg_link_status_bandwidth_status,
                                                               cfg_link_status_dll_active,
                                                               (LINK_STATUS_SLOT_CLOCK_CONFIG == "TRUE") ? 1'b1 : 1'b0,
                                                               cfg_link_status_link_training,
                                                               1'b0,
                                                               {2'b00, cfg_link_status_negotiated_link_width},
                                                               {2'b00, cfg_link_status_current_speed} };

  assign                                        cfg_lcommand = {4'b0,
                                                                cfg_link_control_auto_bandwidth_int_en,
                                                                cfg_link_control_bandwidth_int_en,
                                                                cfg_link_control_hw_auto_width_dis,
                                                                cfg_link_control_clock_pm_en,
                                                                cfg_link_control_extended_sync,
                                                                cfg_link_control_common_clock,
                                                                cfg_link_control_retrain_link,
                                                                cfg_link_control_linkdisable,
                                                                cfg_link_control_rcb,
                                                                1'b0,
                                                                cfg_link_control_aspm_control };

  assign                                        cfg_bus_number = cfg_bus_number_d;

  assign                                        cfg_device_number = cfg_device_number_d;

  assign                                        cfg_function_number =  cfg_function_number_d;

  assign                                        cfg_dcommand2 = {11'b0,
                                                                 cfg_dev_control2_cpltimeout_dis,
                                                                 cfg_dev_control2_cpltimeout_val};


  // Capture Bus/Device/Function number

  always @(posedge user_clk_out) begin
    if      (!user_lnk_up)      cfg_bus_number_d <= 8'b0;
    else if (~cfg_msg_received) cfg_bus_number_d <= cfg_msg_data[15:8];
  end

  always @(posedge user_clk_out) begin
      if      (!user_lnk_up)      cfg_device_number_d <= 5'b0;
      else if (~cfg_msg_received) cfg_device_number_d <= cfg_msg_data[7:3];
  end

  always @(posedge user_clk_out) begin
      if      (!user_lnk_up)      cfg_function_number_d <= 3'b0;
      else if (~cfg_msg_received) cfg_function_number_d <= cfg_msg_data[2:0];
  end

  // Generate user_lnk_up

FDCP #(

  .INIT(1'b0)

) trn_lnk_up_n_i (

  .Q (user_lnk_up),
  .D (!trn_lnk_up_n_int1),
  .C (user_clk_out),
  .CLR (1'b0),
  .PRE (1'b0)

);

FDCP #(

  .INIT(1'b1)

) trn_lnk_up_n_int_i (

  .Q (trn_lnk_up_n_int1),
  .D (trn_lnk_up_n_int),
  .C (user_clk_out),
  .CLR (1'b0),
  .PRE (1'b0)

);

  // Generate user_reset_out

FDCP #(

  .INIT(1'b1)

) trn_reset_n_i (

  .Q (user_reset_out),
  .D (!(trn_reset_n_int1 & ~phy_rdy_n)),
  .C (user_clk_out),
  .CLR (~sys_reset_n_d),
  .PRE (1'b0)

);

FDCP #(

  .INIT(1'b0)

) trn_reset_n_int_i (

  .Q (trn_reset_n_int1 ),
  .D (trn_reset_n_int & ~phy_rdy_n),
  .C (user_clk_out),
  .CLR (~sys_reset_n_d),
  .PRE (1'b0)

);

// AXI Basic Bridge
// Converts between TRN and AXI

axi_basic_top #(
  .C_DATA_WIDTH     (64),                 // RX/TX interface data width

  .C_FAMILY         ("V6"),               // Targeted FPGA family
  .C_ROOT_PORT      ("FALSE"),            // PCIe block is in root port mode
  .C_PM_PRIORITY    ("FALSE")             // Disable TX packet boundary thrtl

  ) axi_basic_top (
  //---------------------------------------------//
  // User Design I/O                             //
  //---------------------------------------------//

  // AXI TX
  //-----------
  .s_axis_tx_tdata          (s_axis_tx_tdata),          //  input
  .s_axis_tx_tvalid         (s_axis_tx_tvalid),         //  input
  .s_axis_tx_tready         (s_axis_tx_tready),         //  output
  .s_axis_tx_tkeep          (s_axis_tx_tkeep),          //  input
  .s_axis_tx_tlast          (s_axis_tx_tlast),          //  input
  .s_axis_tx_tuser          (s_axis_tx_tuser),          //  input

    // AXI RX
    //-----------
  .m_axis_rx_tdata          (m_axis_rx_tdata),          //  output
  .m_axis_rx_tvalid         (m_axis_rx_tvalid),         //  output
  .m_axis_rx_tready         (m_axis_rx_tready),         //  input
  .m_axis_rx_tkeep          (m_axis_rx_tkeep),          //  output
  .m_axis_rx_tlast          (m_axis_rx_tlast),          //  output
  .m_axis_rx_tuser          (m_axis_rx_tuser),          //  output

    // User Misc.
    //-----------
  .user_turnoff_ok          (cfg_turnoff_ok),           //  input
  .user_tcfg_gnt            (tx_cfg_gnt),               //  input

    //---------------------------------------------//
    // PCIe Block I/O                              //
    //---------------------------------------------//

    // TRN TX
    //-----------
  .trn_td                   (trn_td),                   //  output
  .trn_tsof                 (trn_tsof),                 //  output
  .trn_teof                 (trn_teof),                 //  output
  .trn_tsrc_rdy             (trn_tsrc_rdy),             //  output
  .trn_tdst_rdy             (!trn_tdst_rdy_n),          //  input
  .trn_tsrc_dsc             (trn_tsrc_dsc),             //  output
  .trn_trem                 (trn_trem),                 //  output
  .trn_terrfwd              (trn_terrfwd),              //  output
  .trn_tstr                 (trn_tstr),                 //  output
  .trn_tbuf_av              (tx_buf_av),                //  input
  .trn_tecrc_gen            (trn_tecrc_gen),            //  output

    // TRN RX
    //-----------
  .trn_rd                   (trn_rd),                   //  input
  .trn_rsof                 (!trn_rsof_n),              //  input
  .trn_reof                 (!trn_reof_n),              //  input
  .trn_rsrc_rdy             (!trn_rsrc_rdy_n),          //  input
  .trn_rdst_rdy             (trn_rdst_rdy),             //  output
  .trn_rsrc_dsc             (!trn_rsrc_dsc_n),          //  input
  .trn_rrem                 (~trn_rrem_n),              //  input
  .trn_rerrfwd              (!trn_rerrfwd_n),           //  input
  .trn_rbar_hit             (~trn_rbar_hit_n),          //  input
  .trn_recrc_err            (trn_recrc_err),            //  input

    // TRN Misc.
    //-----------
  .trn_tcfg_req             (tx_cfg_req),               //  input
  .trn_tcfg_gnt             (trn_tcfg_gnt),             //  output
  .trn_lnk_up               (user_lnk_up),              //  input

    // Artix/Kintex/Virtex PM
    //-----------
  .cfg_pcie_link_state      (cfg_pcie_link_state),      //  input

    // Virtex6 PM
    //-----------
  .cfg_pm_send_pme_to       (1'b0),                     //  input  NOT USED FOR EP
  .cfg_pmcsr_powerstate     (cfg_pmcsr_powerstate),     //  input
  .trn_rdllp_data           (trn_rdllp_data),           //  input
  .trn_rdllp_src_rdy        (!trn_rdllp_src_rdy_n),     //  input

    // Power Mgmt for S6/V6
    //-----------
  .cfg_to_turnoff           (cfg_to_turnoff),           //  input
  .cfg_turnoff_ok           (cfg_turnoff_ok_w),         //  output

    // System
    //-----------
  .user_clk                 (user_clk_out),             //  input
  .user_rst                 (user_reset_out),           //  input
  .np_counter               ()                          //  output
);



//-------------------------------------------------------
// PCI Express Reset Delay Module
//-------------------------------------------------------

pcie_reset_delay_v6 #(

  .PL_FAST_TRAIN          ( PL_FAST_TRAIN ),
  .REF_CLK_FREQ           ( REF_CLK_FREQ )

)
pcie_reset_delay_i (

  .ref_clk                ( TxOutClk_bufg ),
  .sys_reset_n            ( !sys_reset ),
  .delayed_sys_reset_n    ( sys_reset_n_d )

);

//-------------------------------------------------------
// PCI Express Clocking Module
//-------------------------------------------------------

pcie_clocking_v6 #(

  .CAP_LINK_WIDTH(LINK_CAP_MAX_LINK_WIDTH),
  .CAP_LINK_SPEED(LINK_CAP_MAX_LINK_SPEED),
  .REF_CLK_FREQ(REF_CLK_FREQ),
  .USER_CLK_FREQ(USER_CLK_FREQ)

)
pcie_clocking_i (

  .sys_clk                 ( TxOutClk ),
  .gt_pll_lock             ( gt_pll_lock ),
  .sel_lnk_rate            ( pl_sel_link_rate ),
  .sel_lnk_width           ( pl_sel_link_width ),

  .sys_clk_bufg            ( TxOutClk_bufg ),
  .pipe_clk                ( pipe_clk ),
  .user_clk                ( user_clk_out ),
  .block_clk               ( block_clk ),
  .drp_clk                 ( drp_clk ),
  .clock_locked            ( clock_locked )

);

//-------------------------------------------------------
// Virtex6 PCI Express Block Module
//-------------------------------------------------------

pcie_2_0_v6 #(

  .REF_CLK_FREQ ( REF_CLK_FREQ ),
  .PIPE_PIPELINE_STAGES ( PIPE_PIPELINE_STAGES ),
  .AER_BASE_PTR ( AER_BASE_PTR ),
  .AER_CAP_ECRC_CHECK_CAPABLE ( AER_CAP_ECRC_CHECK_CAPABLE ),
  .AER_CAP_ECRC_GEN_CAPABLE ( AER_CAP_ECRC_GEN_CAPABLE ),
  .AER_CAP_ID ( AER_CAP_ID ),
  .AER_CAP_INT_MSG_NUM_MSI ( AER_CAP_INT_MSG_NUM_MSI ),
  .AER_CAP_INT_MSG_NUM_MSIX ( AER_CAP_INT_MSG_NUM_MSIX ),
  .AER_CAP_NEXTPTR ( AER_CAP_NEXTPTR ),
  .AER_CAP_ON ( AER_CAP_ON ),
  .AER_CAP_PERMIT_ROOTERR_UPDATE ( AER_CAP_PERMIT_ROOTERR_UPDATE ),
  .AER_CAP_VERSION ( AER_CAP_VERSION ),
  .ALLOW_X8_GEN2 ( ALLOW_X8_GEN2 ),
  .BAR0 ( BAR0 ),
  .BAR1 ( BAR1 ),
  .BAR2 ( BAR2 ),
  .BAR3 ( BAR3 ),
  .BAR4 ( BAR4 ),
  .BAR5 ( BAR5 ),
  .CAPABILITIES_PTR ( CAPABILITIES_PTR ),
  .CARDBUS_CIS_POINTER ( CARDBUS_CIS_POINTER ),
  .CLASS_CODE ( CLASS_CODE ),
  .CMD_INTX_IMPLEMENTED ( CMD_INTX_IMPLEMENTED ),
  .CPL_TIMEOUT_DISABLE_SUPPORTED ( CPL_TIMEOUT_DISABLE_SUPPORTED ),
  .CPL_TIMEOUT_RANGES_SUPPORTED ( CPL_TIMEOUT_RANGES_SUPPORTED ),
  .CRM_MODULE_RSTS ( CRM_MODULE_RSTS ),
  .DEV_CAP_ENABLE_SLOT_PWR_LIMIT_SCALE ( DEV_CAP_ENABLE_SLOT_PWR_LIMIT_SCALE ),
  .DEV_CAP_ENABLE_SLOT_PWR_LIMIT_VALUE ( DEV_CAP_ENABLE_SLOT_PWR_LIMIT_VALUE ),
  .DEV_CAP_ENDPOINT_L0S_LATENCY ( DEV_CAP_ENDPOINT_L0S_LATENCY ),
  .DEV_CAP_ENDPOINT_L1_LATENCY ( DEV_CAP_ENDPOINT_L1_LATENCY ),
  .DEV_CAP_EXT_TAG_SUPPORTED ( DEV_CAP_EXT_TAG_SUPPORTED ),
  .DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE ( DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE ),
  .DEV_CAP_MAX_PAYLOAD_SUPPORTED ( DEV_CAP_MAX_PAYLOAD_SUPPORTED ),
  .DEV_CAP_PHANTOM_FUNCTIONS_SUPPORT ( DEV_CAP_PHANTOM_FUNCTIONS_SUPPORT ),
  .DEV_CAP_ROLE_BASED_ERROR ( DEV_CAP_ROLE_BASED_ERROR ),
  .DEV_CAP_RSVD_14_12 ( DEV_CAP_RSVD_14_12 ),
  .DEV_CAP_RSVD_17_16 ( DEV_CAP_RSVD_17_16 ),
  .DEV_CAP_RSVD_31_29 ( DEV_CAP_RSVD_31_29 ),
  .DEV_CONTROL_AUX_POWER_SUPPORTED ( DEV_CONTROL_AUX_POWER_SUPPORTED ),
  .DEVICE_ID ( DEVICE_ID ),
  .DISABLE_ASPM_L1_TIMER ( DISABLE_ASPM_L1_TIMER ),
  .DISABLE_BAR_FILTERING ( DISABLE_BAR_FILTERING ),
  .DISABLE_ID_CHECK ( DISABLE_ID_CHECK ),
  .DISABLE_LANE_REVERSAL ( DISABLE_LANE_REVERSAL ),
  .DISABLE_RX_TC_FILTER ( DISABLE_RX_TC_FILTER ),
  .DISABLE_SCRAMBLING ( DISABLE_SCRAMBLING ),
  .DNSTREAM_LINK_NUM ( DNSTREAM_LINK_NUM ),
  .DSN_BASE_PTR ( DSN_BASE_PTR ),
  .DSN_CAP_ID ( DSN_CAP_ID ),
  .DSN_CAP_NEXTPTR ( DSN_CAP_NEXTPTR ),
  .DSN_CAP_ON ( DSN_CAP_ON ),
  .DSN_CAP_VERSION ( DSN_CAP_VERSION ),
  .ENABLE_MSG_ROUTE ( ENABLE_MSG_ROUTE ),
  .ENABLE_RX_TD_ECRC_TRIM ( ENABLE_RX_TD_ECRC_TRIM ),
  .ENTER_RVRY_EI_L0 ( ENTER_RVRY_EI_L0 ),
  .EXPANSION_ROM ( EXPANSION_ROM ),
  .EXT_CFG_CAP_PTR ( EXT_CFG_CAP_PTR ),
  .EXT_CFG_XP_CAP_PTR ( EXT_CFG_XP_CAP_PTR ),
  .HEADER_TYPE ( HEADER_TYPE ),
  .INFER_EI ( INFER_EI ),
  .INTERRUPT_PIN ( INTERRUPT_PIN ),
  .IS_SWITCH ( IS_SWITCH ),
  .LAST_CONFIG_DWORD ( LAST_CONFIG_DWORD ),
  .LINK_CAP_ASPM_SUPPORT ( LINK_CAP_ASPM_SUPPORT ),
  .LINK_CAP_CLOCK_POWER_MANAGEMENT ( LINK_CAP_CLOCK_POWER_MANAGEMENT ),
  .LINK_CAP_DLL_LINK_ACTIVE_REPORTING_CAP ( LINK_CAP_DLL_LINK_ACTIVE_REPORTING_CAP ),
  .LINK_CAP_LINK_BANDWIDTH_NOTIFICATION_CAP ( LINK_CAP_LINK_BANDWIDTH_NOTIFICATION_CAP ),
  .LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN1 ( LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN1 ),
  .LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN2 ( LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN2 ),
  .LINK_CAP_L0S_EXIT_LATENCY_GEN1 ( LINK_CAP_L0S_EXIT_LATENCY_GEN1 ),
  .LINK_CAP_L0S_EXIT_LATENCY_GEN2 ( LINK_CAP_L0S_EXIT_LATENCY_GEN2 ),
  .LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN1 ( LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN1 ),
  .LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN2 ( LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN2 ),
  .LINK_CAP_L1_EXIT_LATENCY_GEN1 ( LINK_CAP_L1_EXIT_LATENCY_GEN1 ),
  .LINK_CAP_L1_EXIT_LATENCY_GEN2 ( LINK_CAP_L1_EXIT_LATENCY_GEN2 ),
  .LINK_CAP_MAX_LINK_SPEED ( LINK_CAP_MAX_LINK_SPEED ),
  .LINK_CAP_MAX_LINK_WIDTH ( LINK_CAP_MAX_LINK_WIDTH ),
  .LINK_CAP_RSVD_23_22 ( LINK_CAP_RSVD_23_22 ),
  .LINK_CAP_SURPRISE_DOWN_ERROR_CAPABLE ( LINK_CAP_SURPRISE_DOWN_ERROR_CAPABLE ),
  .LINK_CONTROL_RCB ( LINK_CONTROL_RCB ),
  .LINK_CTRL2_DEEMPHASIS ( LINK_CTRL2_DEEMPHASIS ),
  .LINK_CTRL2_HW_AUTONOMOUS_SPEED_DISABLE ( LINK_CTRL2_HW_AUTONOMOUS_SPEED_DISABLE ),
  .LINK_CTRL2_TARGET_LINK_SPEED ( LINK_CTRL2_TARGET_LINK_SPEED ),
  .LINK_STATUS_SLOT_CLOCK_CONFIG ( LINK_STATUS_SLOT_CLOCK_CONFIG ),
  .LL_ACK_TIMEOUT ( LL_ACK_TIMEOUT ),
  .LL_ACK_TIMEOUT_EN ( LL_ACK_TIMEOUT_EN ),
  .LL_ACK_TIMEOUT_FUNC ( LL_ACK_TIMEOUT_FUNC ),
  .LL_REPLAY_TIMEOUT ( LL_REPLAY_TIMEOUT ),
  .LL_REPLAY_TIMEOUT_EN ( LL_REPLAY_TIMEOUT_EN ),
  .LL_REPLAY_TIMEOUT_FUNC ( LL_REPLAY_TIMEOUT_FUNC ),
  .LTSSM_MAX_LINK_WIDTH ( LTSSM_MAX_LINK_WIDTH ),
  .MSI_BASE_PTR ( MSI_BASE_PTR ),
  .MSI_CAP_ID ( MSI_CAP_ID ),
  .MSI_CAP_MULTIMSGCAP ( MSI_CAP_MULTIMSGCAP ),
  .MSI_CAP_MULTIMSG_EXTENSION ( MSI_CAP_MULTIMSG_EXTENSION ),
  .MSI_CAP_NEXTPTR ( MSI_CAP_NEXTPTR ),
  .MSI_CAP_ON ( MSI_CAP_ON ),
  .MSI_CAP_PER_VECTOR_MASKING_CAPABLE ( MSI_CAP_PER_VECTOR_MASKING_CAPABLE ),
  .MSI_CAP_64_BIT_ADDR_CAPABLE ( MSI_CAP_64_BIT_ADDR_CAPABLE ),
  .MSIX_BASE_PTR ( MSIX_BASE_PTR ),
  .MSIX_CAP_ID ( MSIX_CAP_ID ),
  .MSIX_CAP_NEXTPTR ( MSIX_CAP_NEXTPTR ),
  .MSIX_CAP_ON ( MSIX_CAP_ON ),
  .MSIX_CAP_PBA_BIR ( MSIX_CAP_PBA_BIR ),
  .MSIX_CAP_PBA_OFFSET ( MSIX_CAP_PBA_OFFSET ),
  .MSIX_CAP_TABLE_BIR ( MSIX_CAP_TABLE_BIR ),
  .MSIX_CAP_TABLE_OFFSET ( MSIX_CAP_TABLE_OFFSET ),
  .MSIX_CAP_TABLE_SIZE ( MSIX_CAP_TABLE_SIZE ),
  .N_FTS_COMCLK_GEN1 ( N_FTS_COMCLK_GEN1 ),
  .N_FTS_COMCLK_GEN2 ( N_FTS_COMCLK_GEN2 ),
  .N_FTS_GEN1 ( N_FTS_GEN1 ),
  .N_FTS_GEN2 ( N_FTS_GEN2 ),
  .PCIE_BASE_PTR ( PCIE_BASE_PTR ),
  .PCIE_CAP_CAPABILITY_ID ( PCIE_CAP_CAPABILITY_ID ),
  .PCIE_CAP_CAPABILITY_VERSION ( PCIE_CAP_CAPABILITY_VERSION ),
  .PCIE_CAP_DEVICE_PORT_TYPE ( PCIE_CAP_DEVICE_PORT_TYPE ),
  .PCIE_CAP_INT_MSG_NUM ( PCIE_CAP_INT_MSG_NUM ),
  .PCIE_CAP_NEXTPTR ( PCIE_CAP_NEXTPTR ),
  .PCIE_CAP_ON ( PCIE_CAP_ON ),
  .PCIE_CAP_RSVD_15_14 ( PCIE_CAP_RSVD_15_14 ),
  .PCIE_CAP_SLOT_IMPLEMENTED ( PCIE_CAP_SLOT_IMPLEMENTED ),
  .PCIE_REVISION ( PCIE_REVISION ),
  .PGL0_LANE ( PGL0_LANE ),
  .PGL1_LANE ( PGL1_LANE ),
  .PGL2_LANE ( PGL2_LANE ),
  .PGL3_LANE ( PGL3_LANE ),
  .PGL4_LANE ( PGL4_LANE ),
  .PGL5_LANE ( PGL5_LANE ),
  .PGL6_LANE ( PGL6_LANE ),
  .PGL7_LANE ( PGL7_LANE ),
  .PL_AUTO_CONFIG ( PL_AUTO_CONFIG ),
  .PL_FAST_TRAIN ( PL_FAST_TRAIN ),
  .PM_BASE_PTR ( PM_BASE_PTR ),
  .PM_CAP_AUXCURRENT ( PM_CAP_AUXCURRENT ),
  .PM_CAP_DSI ( PM_CAP_DSI ),
  .PM_CAP_D1SUPPORT ( PM_CAP_D1SUPPORT ),
  .PM_CAP_D2SUPPORT ( PM_CAP_D2SUPPORT ),
  .PM_CAP_ID ( PM_CAP_ID ),
  .PM_CAP_NEXTPTR ( PM_CAP_NEXTPTR ),
  .PM_CAP_ON ( PM_CAP_ON ),
  .PM_CAP_PME_CLOCK ( PM_CAP_PME_CLOCK ),
  .PM_CAP_PMESUPPORT ( PM_CAP_PMESUPPORT ),
  .PM_CAP_RSVD_04 ( PM_CAP_RSVD_04 ),
  .PM_CAP_VERSION ( PM_CAP_VERSION ),
  .PM_CSR_BPCCEN ( PM_CSR_BPCCEN ),
  .PM_CSR_B2B3 ( PM_CSR_B2B3 ),
  .PM_CSR_NOSOFTRST ( PM_CSR_NOSOFTRST ),
  .PM_DATA_SCALE0 ( PM_DATA_SCALE0 ),
  .PM_DATA_SCALE1 ( PM_DATA_SCALE1 ),
  .PM_DATA_SCALE2 ( PM_DATA_SCALE2 ),
  .PM_DATA_SCALE3 ( PM_DATA_SCALE3 ),
  .PM_DATA_SCALE4 ( PM_DATA_SCALE4 ),
  .PM_DATA_SCALE5 ( PM_DATA_SCALE5 ),
  .PM_DATA_SCALE6 ( PM_DATA_SCALE6 ),
  .PM_DATA_SCALE7 ( PM_DATA_SCALE7 ),
  .PM_DATA0 ( PM_DATA0 ),
  .PM_DATA1 ( PM_DATA1 ),
  .PM_DATA2 ( PM_DATA2 ),
  .PM_DATA3 ( PM_DATA3 ),
  .PM_DATA4 ( PM_DATA4 ),
  .PM_DATA5 ( PM_DATA5 ),
  .PM_DATA6 ( PM_DATA6 ),
  .PM_DATA7 ( PM_DATA7 ),
  .RECRC_CHK ( RECRC_CHK ),
  .RECRC_CHK_TRIM ( RECRC_CHK_TRIM ),
  .REVISION_ID ( REVISION_ID ),
  .ROOT_CAP_CRS_SW_VISIBILITY ( ROOT_CAP_CRS_SW_VISIBILITY ),
  .SELECT_DLL_IF ( SELECT_DLL_IF ),
  .SLOT_CAP_ATT_BUTTON_PRESENT ( SLOT_CAP_ATT_BUTTON_PRESENT ),
  .SLOT_CAP_ATT_INDICATOR_PRESENT ( SLOT_CAP_ATT_INDICATOR_PRESENT ),
  .SLOT_CAP_ELEC_INTERLOCK_PRESENT ( SLOT_CAP_ELEC_INTERLOCK_PRESENT ),
  .SLOT_CAP_HOTPLUG_CAPABLE ( SLOT_CAP_HOTPLUG_CAPABLE ),
  .SLOT_CAP_HOTPLUG_SURPRISE ( SLOT_CAP_HOTPLUG_SURPRISE ),
  .SLOT_CAP_MRL_SENSOR_PRESENT ( SLOT_CAP_MRL_SENSOR_PRESENT ),
  .SLOT_CAP_NO_CMD_COMPLETED_SUPPORT ( SLOT_CAP_NO_CMD_COMPLETED_SUPPORT ),
  .SLOT_CAP_PHYSICAL_SLOT_NUM ( SLOT_CAP_PHYSICAL_SLOT_NUM ),
  .SLOT_CAP_POWER_CONTROLLER_PRESENT ( SLOT_CAP_POWER_CONTROLLER_PRESENT ),
  .SLOT_CAP_POWER_INDICATOR_PRESENT ( SLOT_CAP_POWER_INDICATOR_PRESENT ),
  .SLOT_CAP_SLOT_POWER_LIMIT_SCALE ( SLOT_CAP_SLOT_POWER_LIMIT_SCALE ),
  .SLOT_CAP_SLOT_POWER_LIMIT_VALUE ( SLOT_CAP_SLOT_POWER_LIMIT_VALUE ),
  .SPARE_BIT0 ( SPARE_BIT0 ),
  .SPARE_BIT1 ( SPARE_BIT1 ),
  .SPARE_BIT2 ( SPARE_BIT2 ),
  .SPARE_BIT3 ( SPARE_BIT3 ),
  .SPARE_BIT4 ( SPARE_BIT4 ),
  .SPARE_BIT5 ( SPARE_BIT5 ),
  .SPARE_BIT6 ( SPARE_BIT6 ),
  .SPARE_BIT7 ( SPARE_BIT7 ),
  .SPARE_BIT8 ( SPARE_BIT8 ),
  .SPARE_BYTE0 ( SPARE_BYTE0 ),
  .SPARE_BYTE1 ( SPARE_BYTE1 ),
  .SPARE_BYTE2 ( SPARE_BYTE2 ),
  .SPARE_BYTE3 ( SPARE_BYTE3 ),
  .SPARE_WORD0 ( SPARE_WORD0 ),
  .SPARE_WORD1 ( SPARE_WORD1 ),
  .SPARE_WORD2 ( SPARE_WORD2 ),
  .SPARE_WORD3 ( SPARE_WORD3 ),
  .SUBSYSTEM_ID ( SUBSYSTEM_ID ),
  .SUBSYSTEM_VENDOR_ID ( SUBSYSTEM_VENDOR_ID ),
  .TL_RBYPASS ( TL_RBYPASS ),
  .TL_RX_RAM_RADDR_LATENCY ( TL_RX_RAM_RADDR_LATENCY ),
  .TL_RX_RAM_RDATA_LATENCY ( TL_RX_RAM_RDATA_LATENCY ),
  .TL_RX_RAM_WRITE_LATENCY ( TL_RX_RAM_WRITE_LATENCY ),
  .TL_TFC_DISABLE ( TL_TFC_DISABLE ),
  .TL_TX_CHECKS_DISABLE ( TL_TX_CHECKS_DISABLE ),
  .TL_TX_RAM_RADDR_LATENCY ( TL_TX_RAM_RADDR_LATENCY ),
  .TL_TX_RAM_RDATA_LATENCY ( TL_TX_RAM_RDATA_LATENCY ),
  .TL_TX_RAM_WRITE_LATENCY ( TL_TX_RAM_WRITE_LATENCY ),
  .UPCONFIG_CAPABLE ( UPCONFIG_CAPABLE ),
  .UPSTREAM_FACING ( UPSTREAM_FACING ),
  .EXIT_LOOPBACK_ON_EI ( EXIT_LOOPBACK_ON_EI ),
  .UR_INV_REQ ( UR_INV_REQ ),
  .USER_CLK_FREQ ( USER_CLK_FREQ ),
  .VC_BASE_PTR ( VC_BASE_PTR ),
  .VC_CAP_ID ( VC_CAP_ID ),
  .VC_CAP_NEXTPTR ( VC_CAP_NEXTPTR ),
  .VC_CAP_ON ( VC_CAP_ON ),
  .VC_CAP_REJECT_SNOOP_TRANSACTIONS ( VC_CAP_REJECT_SNOOP_TRANSACTIONS ),
  .VC_CAP_VERSION ( VC_CAP_VERSION ),
  .VC0_CPL_INFINITE ( VC0_CPL_INFINITE ),
  .VC0_RX_RAM_LIMIT ( VC0_RX_RAM_LIMIT ),
  .VC0_TOTAL_CREDITS_CD ( VC0_TOTAL_CREDITS_CD ),
  .VC0_TOTAL_CREDITS_CH ( VC0_TOTAL_CREDITS_CH ),
  .VC0_TOTAL_CREDITS_NPH ( VC0_TOTAL_CREDITS_NPH ),
  .VC0_TOTAL_CREDITS_PD ( VC0_TOTAL_CREDITS_PD ),
  .VC0_TOTAL_CREDITS_PH ( VC0_TOTAL_CREDITS_PH ),
  .VC0_TX_LASTPACKET ( VC0_TX_LASTPACKET ),
  .VENDOR_ID ( VENDOR_ID ),
  .VSEC_BASE_PTR ( VSEC_BASE_PTR ),
  .VSEC_CAP_HDR_ID ( VSEC_CAP_HDR_ID ),
  .VSEC_CAP_HDR_LENGTH ( VSEC_CAP_HDR_LENGTH ),
  .VSEC_CAP_HDR_REVISION ( VSEC_CAP_HDR_REVISION ),
  .VSEC_CAP_ID ( VSEC_CAP_ID ),
  .VSEC_CAP_IS_LINK_VISIBLE ( VSEC_CAP_IS_LINK_VISIBLE ),
  .VSEC_CAP_NEXTPTR ( VSEC_CAP_NEXTPTR ),
  .VSEC_CAP_ON ( VSEC_CAP_ON ),
  .VSEC_CAP_VERSION ( VSEC_CAP_VERSION )

)
pcie_2_0_i (

  .PCIEXPRXN( pci_exp_rxn ),
  .PCIEXPRXP( pci_exp_rxp ),
  .PCIEXPTXN( pci_exp_txn ),
  .PCIEXPTXP( pci_exp_txp ),

  .SYSCLK( sys_clk ),
  .TRNLNKUPN( trn_lnk_up_n_int ),

  .FUNDRSTN (sys_reset_n_d),
  .PHYRDYN( phy_rdy_n ),

  .LNKCLKEN ( ),
  .USERRSTN( trn_reset_n_int ),
  .RECEIVEDFUNCLVLRSTN( rx_func_level_reset_n ),
  .SYSRSTN( ~phy_rdy_n ),
  .PLRSTN( 1'b1 ),
  .DLRSTN( 1'b1 ),
  .TLRSTN( 1'b1 ),
  .FUNCLVLRSTN( 1'b1 ),
  .CMRSTN( 1'b1 ),
  .CMSTICKYRSTN( 1'b1 ),

  .TRNRBARHITN( trn_rbar_hit_n ),
  .TRNRD( trn_rd ),
  .TRNRECRCERRN( trn_recrc_err_n ),
  .TRNREOFN( trn_reof_n ),
  .TRNRERRFWDN( trn_rerrfwd_n ),
  .TRNRREMN( trn_rrem_n ),
  .TRNRSOFN( trn_rsof_n ),
  .TRNRSRCDSCN( trn_rsrc_dsc_n ),
  .TRNRSRCRDYN( trn_rsrc_rdy_n ),
  .TRNRDSTRDYN( !trn_rdst_rdy ),
  .TRNRNPOKN( !rx_np_ok ),

  .TRNTBUFAV( tx_buf_av ),
  .TRNTCFGREQN( trn_tcfg_req_n ),
  .TRNTDLLPDSTRDYN( ),
  .TRNTDSTRDYN( trn_tdst_rdy_n ),
  .TRNTERRDROPN( trn_terr_drop_n ),
  .TRNTCFGGNTN( !trn_tcfg_gnt ),
  .TRNTD( trn_td ),
  .TRNTDLLPDATA( 32'b0 ),
  .TRNTDLLPSRCRDYN( 1'b1 ),
  .TRNTECRCGENN( 1'b1 ),
  .TRNTEOFN( !trn_teof ),
  .TRNTERRFWDN( !trn_terrfwd ),
  .TRNTREMN( ~trn_trem ),
  .TRNTSOFN( !trn_tsof ),
  .TRNTSRCDSCN( !trn_tsrc_dsc ),
  .TRNTSRCRDYN( !trn_tsrc_rdy ),
  .TRNTSTRN( !trn_tstr ),

  .TRNFCCPLD( fc_cpld ),
  .TRNFCCPLH( fc_cplh ),
  .TRNFCNPD( fc_npd ),
  .TRNFCNPH( fc_nph ),
  .TRNFCPD( fc_pd ),
  .TRNFCPH( fc_ph ),
  .TRNFCSEL( fc_sel ),

  .CFGAERECRCCHECKEN(),
  .CFGAERECRCGENEN(),
  .CFGCOMMANDBUSMASTERENABLE( cfg_cmd_bme ),
  .CFGCOMMANDINTERRUPTDISABLE( cfg_cmd_intdis ),
  .CFGCOMMANDIOENABLE( cfg_cmd_io_en ),
  .CFGCOMMANDMEMENABLE( cfg_cmd_mem_en ),
  .CFGCOMMANDSERREN( cfg_cmd_serr_en ),
  .CFGDEVCONTROLAUXPOWEREN( cfg_dev_control_aux_power_en ),
  .CFGDEVCONTROLCORRERRREPORTINGEN( cfg_dev_control_corr_err_reporting_en ),
  .CFGDEVCONTROLENABLERO( cfg_dev_control_enable_relaxed_order ),
  .CFGDEVCONTROLEXTTAGEN( cfg_dev_control_ext_tag_en ),
  .CFGDEVCONTROLFATALERRREPORTINGEN( cfg_dev_control_fatal_err_reporting_en ),
  .CFGDEVCONTROLMAXPAYLOAD( cfg_dev_control_maxpayload ),
  .CFGDEVCONTROLMAXREADREQ( cfg_dev_control_max_read_req ),
  .CFGDEVCONTROLNONFATALREPORTINGEN( cfg_dev_control_non_fatal_reporting_en ),
  .CFGDEVCONTROLNOSNOOPEN( cfg_dev_control_nosnoop_en ),
  .CFGDEVCONTROLPHANTOMEN( cfg_dev_control_phantom_en ),
  .CFGDEVCONTROLURERRREPORTINGEN( cfg_dev_control_ur_err_reporting_en ),
  .CFGDEVCONTROL2CPLTIMEOUTDIS( cfg_dev_control2_cpltimeout_dis ),
  .CFGDEVCONTROL2CPLTIMEOUTVAL( cfg_dev_control2_cpltimeout_val ),
  .CFGDEVSTATUSCORRERRDETECTED( cfg_dev_status_corr_err_detected ),
  .CFGDEVSTATUSFATALERRDETECTED( cfg_dev_status_fatal_err_detected ),
  .CFGDEVSTATUSNONFATALERRDETECTED( cfg_dev_status_nonfatal_err_detected ),
  .CFGDEVSTATUSURDETECTED( cfg_dev_status_ur_detected ),
  .CFGDO( cfg_do ),
  .CFGERRAERHEADERLOGSETN(),
  .CFGERRCPLRDYN( cfg_err_cpl_rdy_n ),
  .CFGINTERRUPTDO( cfg_interrupt_do ),
  .CFGINTERRUPTMMENABLE( cfg_interrupt_mmenable ),
  .CFGINTERRUPTMSIENABLE( cfg_interrupt_msienable ),
  .CFGINTERRUPTMSIXENABLE( cfg_interrupt_msixenable ),
  .CFGINTERRUPTMSIXFM( cfg_interrupt_msixfm ),
  .CFGINTERRUPTRDYN( cfg_interrupt_rdy_n ),
  .CFGLINKCONTROLRCB( cfg_link_control_rcb ),
  .CFGLINKCONTROLASPMCONTROL( cfg_link_control_aspm_control ),
  .CFGLINKCONTROLAUTOBANDWIDTHINTEN( cfg_link_control_auto_bandwidth_int_en ),
  .CFGLINKCONTROLBANDWIDTHINTEN( cfg_link_control_bandwidth_int_en ),
  .CFGLINKCONTROLCLOCKPMEN( cfg_link_control_clock_pm_en ),
  .CFGLINKCONTROLCOMMONCLOCK( cfg_link_control_common_clock ),
  .CFGLINKCONTROLEXTENDEDSYNC( cfg_link_control_extended_sync ),
  .CFGLINKCONTROLHWAUTOWIDTHDIS( cfg_link_control_hw_auto_width_dis ),
  .CFGLINKCONTROLLINKDISABLE( cfg_link_control_linkdisable ),
  .CFGLINKCONTROLRETRAINLINK( cfg_link_control_retrain_link ),
  .CFGLINKSTATUSAUTOBANDWIDTHSTATUS( cfg_link_status_autobandwidth_status ),
  .CFGLINKSTATUSBANDWITHSTATUS( cfg_link_status_bandwidth_status ),
  .CFGLINKSTATUSCURRENTSPEED( cfg_link_status_current_speed ),
  .CFGLINKSTATUSDLLACTIVE( cfg_link_status_dll_active ),
  .CFGLINKSTATUSLINKTRAINING( cfg_link_status_link_training ),
  .CFGLINKSTATUSNEGOTIATEDWIDTH( cfg_link_status_negotiated_link_width ),
  .CFGMSGDATA( cfg_msg_data ),
  .CFGMSGRECEIVED( cfg_msg_received ),
  .CFGMSGRECEIVEDASSERTINTA(),
  .CFGMSGRECEIVEDASSERTINTB(),
  .CFGMSGRECEIVEDASSERTINTC(),
  .CFGMSGRECEIVEDASSERTINTD(),
  .CFGMSGRECEIVEDDEASSERTINTA(),
  .CFGMSGRECEIVEDDEASSERTINTB(),
  .CFGMSGRECEIVEDDEASSERTINTC(),
  .CFGMSGRECEIVEDDEASSERTINTD(),
  .CFGMSGRECEIVEDERRCOR(),
  .CFGMSGRECEIVEDERRFATAL(),
  .CFGMSGRECEIVEDERRNONFATAL(),
  .CFGMSGRECEIVEDPMASNAK(),
  .CFGMSGRECEIVEDPMETO( cfg_msg_received_pme_to ),
  .CFGMSGRECEIVEDPMETOACK(),
  .CFGMSGRECEIVEDPMPME(),
  .CFGMSGRECEIVEDSETSLOTPOWERLIMIT(),
  .CFGMSGRECEIVEDUNLOCK(),
  .CFGPCIELINKSTATE( cfg_pcie_link_state ),
  .CFGPMCSRPMEEN ( cfg_pmcsr_pme_en ),
  .CFGPMCSRPMESTATUS ( cfg_pmcsr_pme_status ),
  .CFGPMCSRPOWERSTATE ( cfg_pmcsr_powerstate ),
  .CFGPMRCVASREQL1N(),
  .CFGPMRCVENTERL1N(),
  .CFGPMRCVENTERL23N(),
  .CFGPMRCVREQACKN(),
  .CFGRDWRDONEN( cfg_rd_wr_done_n ),
  .CFGSLOTCONTROLELECTROMECHILCTLPULSE(),
  .CFGTRANSACTION(),
  .CFGTRANSACTIONADDR(),
  .CFGTRANSACTIONTYPE(),
  .CFGVCTCVCMAP(),
  .CFGBYTEENN( cfg_byte_en_n ),
  .CFGDI( cfg_di ),
  .CFGDSBUSNUMBER( 8'b0 ),
  .CFGDSDEVICENUMBER( 5'b0 ),
  .CFGDSFUNCTIONNUMBER( 3'b0 ),
  .CFGDSN( cfg_dsn ),
  .CFGDWADDR( cfg_dwaddr ),
  .CFGERRACSN( 1'b1 ),
  .CFGERRAERHEADERLOG( 128'h0 ),
  .CFGERRCORN( cfg_err_cor_n ),
  .CFGERRCPLABORTN( cfg_err_cpl_abort_n ),
  .CFGERRCPLTIMEOUTN( cfg_err_cpl_timeout_n ),
  .CFGERRCPLUNEXPECTN( cfg_err_cpl_unexpect_n ),
  .CFGERRECRCN( cfg_err_ecrc_n ),
  .CFGERRLOCKEDN( cfg_err_locked_n ),
  .CFGERRPOSTEDN( cfg_err_posted_n ),
  .CFGERRTLPCPLHEADER( cfg_err_tlp_cpl_header ),
  .CFGERRURN( cfg_err_ur_n ),
  .CFGINTERRUPTASSERTN( cfg_interrupt_assert_n ),
  .CFGINTERRUPTDI( cfg_interrupt_di ),
  .CFGINTERRUPTN( cfg_interrupt_n ),
  .CFGPMDIRECTASPML1N( 1'b1 ),
  .CFGPMSENDPMACKN( 1'b1 ),
  .CFGPMSENDPMETON( 1'b1 ),
  .CFGPMSENDPMNAKN( 1'b1 ),
  .CFGPMTURNOFFOKN( cfg_turnoff_ok_n ),
  .CFGPMWAKEN( cfg_pm_wake_n ),
  .CFGPORTNUMBER( 8'h0 ),
  .CFGRDENN( cfg_rd_en_n ),
  .CFGTRNPENDINGN( cfg_trn_pending_n ),
  .CFGWRENN( cfg_wr_en_n ),
  .CFGWRREADONLYN( 1'b1 ),
  .CFGWRRW1CASRWN( 1'b1 ),

  .PLINITIALLINKWIDTH( pl_initial_link_width ),
  .PLLANEREVERSALMODE( pl_lane_reversal_mode ),
  .PLLINKGEN2CAP( pl_link_gen2_capable ),
  .PLLINKPARTNERGEN2SUPPORTED( pl_link_partner_gen2_supported ),
  .PLLINKUPCFGCAP( pl_link_upcfg_capable ),
  .PLLTSSMSTATE( pl_ltssm_state ),
  .PLPHYLNKUPN( ),                                            // Debug
  .PLRECEIVEDHOTRST( pl_received_hot_rst ),
  .PLRXPMSTATE(),                                             // Debug
  .PLSELLNKRATE( pl_sel_link_rate ),
  .PLSELLNKWIDTH( pl_sel_link_width ),
  .PLTXPMSTATE(),                                             // Debug
  .PLDIRECTEDLINKAUTON( pl_directed_link_auton ),
  .PLDIRECTEDLINKCHANGE( pl_directed_link_change ),
  .PLDIRECTEDLINKSPEED( pl_directed_link_speed ),
  .PLDIRECTEDLINKWIDTH( pl_directed_link_width ),
  .PLDOWNSTREAMDEEMPHSOURCE( 1'b1 ),
  .PLUPSTREAMPREFERDEEMPH( pl_upstream_prefer_deemph ),
  .PLTRANSMITHOTRST( 1'b0 ),

  .DBGSCLRA(),
  .DBGSCLRB(),
  .DBGSCLRC(),
  .DBGSCLRD(),
  .DBGSCLRE(),
  .DBGSCLRF(),
  .DBGSCLRG(),
  .DBGSCLRH(),
  .DBGSCLRI(),
  .DBGSCLRJ(),
  .DBGSCLRK(),
  .DBGVECA(),
  .DBGVECB(),
  .DBGVECC(),
  .PLDBGVEC(),
  .DBGMODE( 2'b0 ),
  .DBGSUBMODE( 1'b0 ),
  .PLDBGMODE( 3'b0 ),

  .PCIEDRPDO(),
  .PCIEDRPDRDY(),
  .PCIEDRPCLK(1'b0),
  .PCIEDRPDADDR(9'b0),
  .PCIEDRPDEN(1'b0),
  .PCIEDRPDI(16'b0),
  .PCIEDRPDWE(1'b0),

  .GTPLLLOCK( gt_pll_lock ),
  .PIPECLK( pipe_clk ),
  .USERCLK( user_clk_out ),
  .DRPCLK(drp_clk),
  .CLOCKLOCKED( clock_locked ),
  .TxOutClk(TxOutClk),
  .TRNRDLLPDATA(trn_rdllp_data),
  .TRNRDLLPSRCRDYN(trn_rdllp_src_rdy_n)



);

endmodule
