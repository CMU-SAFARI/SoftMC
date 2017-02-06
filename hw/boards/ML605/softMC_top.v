`timescale 1ps / 1ps

`include "softMC.inc"

module softMC_top #
  (
	parameter TCQ             = 100,
	parameter tCK = 2500, //ps, TODO: let memory clok be 400 Mhz for now
	parameter nCK_PER_CLK     = 2,       // # of memory clocks per CLK
	parameter REFCLK_FREQ     = 200.0,   // IODELAY Reference Clock freq (MHz)
	parameter DRAM_TYPE       = "DDR3",  // Memory I/F type: "DDR3", "DDR2"
	parameter RST_ACT_LOW = 0,
	parameter INPUT_CLK_TYPE = "DIFFERENTIAL",

	parameter CLKFBOUT_MULT_F =6,
	parameter DIVCLK_DIVIDE = 1,
	parameter CLKOUT_DIVIDE = 3,
	 
	// Slot Conifg parameters
	parameter [7:0] SLOT_0_CONFIG = 8'b0000_0001,
	parameter [7:0] SLOT_1_CONFIG = 8'b0000_0000,
    // DRAM bus widths
    parameter BANK_WIDTH      = 3,       // # of bank bits
    parameter CK_WIDTH        = 2,       // # of CK/CK# outputs to memory
    parameter COL_WIDTH       = 10,      // column address width
    parameter nCS_PER_RANK    = 1,       // # of unique CS outputs per rank
    parameter DQ_CNT_WIDTH    = 6,       // = ceil(log2(DQ_WIDTH))
    parameter DQ_WIDTH        = 64,      // # of DQ (data)
    parameter DM_WIDTH        = 8,       // # of DM (data mask)
    parameter DQS_CNT_WIDTH   = 3,       // = ceil(log2(DQS_WIDTH))
    parameter DQS_WIDTH       = 8,       // # of DQS (strobe)
    parameter DRAM_WIDTH      = 8,       // # of DQ per DQS
    parameter ROW_WIDTH       = 16,      // DRAM address bus width
    parameter RANK_WIDTH      = 1,       // log2(CS_WIDTH)
    parameter CS_WIDTH        = 1,       // # of DRAM ranks
    parameter CKE_WIDTH       = 1,       // # of cke outputs 
    parameter CAL_WIDTH       = "HALF",  // # of DRAM ranks to be calibrated
                                         // CAL_WIDTH = CS_WIDTH when "FULL"
                                         // CAL_WIDTH = CS_WIDTH/2 when "HALF"          
    // calibration Address. The address given below will be used for calibration
    // read and write operations. 
    parameter CALIB_ROW_ADD   = 16'h0000,// Calibration row address
    parameter CALIB_COL_ADD   = 12'h000, // Calibration column address
    parameter CALIB_BA_ADD    = 3'h0,    // Calibration bank address 
    // DRAM mode settings
    parameter AL              = "0",     // Additive Latency option
    parameter BURST_MODE      = "8",     // Burst length
    parameter BURST_TYPE      = "SEQ",   // Burst type
    parameter nAL             = 0,       // Additive latency (in clk cyc)
    parameter nCL             = 5,       // Read CAS latency (in clk cyc)
    parameter nCWL            = 5,       // Write CAS latency (in clk cyc)
    parameter tRFC            = 110000,  // Refresh-to-command delay
    parameter OUTPUT_DRV      = "HIGH",  // DRAM reduced output drive option
    parameter REG_CTRL        = "OFF",   // "ON" for registered DIMM
    parameter RTT_NOM         = "60",    // ODT Nominal termination value
    parameter RTT_WR          = "OFF",   // ODT Write termination value
    parameter WRLVL           = "ON",    // Enable write leveling
    // Phase Detector/Read Leveling options
    parameter PHASE_DETECT    = "ON",    // Enable read phase detector
    parameter PD_TAP_REQ      = 0,       // # of IODELAY taps reserved for PD
    parameter PD_MSB_SEL      = 8,       // # of bits in PD response cntr
    parameter PD_DQS0_ONLY    = "ON",    // Enable use of DQS[0] only for
                                         // phase detector
    parameter PD_LHC_WIDTH    = 16,      // sampling averaging cntr widths   
    parameter PD_CALIB_MODE   = "PARALLEL",  // parallel/seq PD calibration
    // IODELAY/BUFFER options
    parameter IBUF_LPWR_MODE  = "OFF",   // Input buffer low power mode
    parameter IODELAY_HP_MODE = "ON",    // IODELAY High Performance Mode
    parameter IODELAY_GRP     = "IODELAY_MIG", // May be assigned unique name
                                               // when mult IP cores in design
    // Pin-out related parameters
    parameter nDQS_COL0       = 3,  // # DQS groups in I/O column #1
    parameter nDQS_COL1       = 5,          // # DQS groups in I/O column #2
    parameter nDQS_COL2       = 0,          // # DQS groups in I/O column #3
    parameter nDQS_COL3       = 0,          // # DQS groups in I/O column #4
    parameter DQS_LOC_COL0    = 24'h020100,
                                            // DQS grps in col #1
    parameter DQS_LOC_COL1    = 40'h0706050403,          // DQS grps in col #2
    parameter DQS_LOC_COL2    = 0,          // DQS grps in col #3
    parameter DQS_LOC_COL3    = 0,          // DQS grps in col #4
    parameter USE_DM_PORT     = 0,          // DM instantation enable
    // Simulation /debug options
    parameter SIM_BYPASS_INIT_CAL = "NONE",   
                                        // Parameter used to force skipping
                                        // or abbreviation of initialization
                                        // and calibration. Overrides
                                        // SIM_INIT_OPTION, SIM_CAL_OPTION,
                                        // and disables various other blocks
    parameter SIM_INIT_OPTION = "NONE", // Skip various initialization steps
    parameter SIM_CAL_OPTION  = "NONE", // Skip various calibration steps
    parameter DEBUG_PORT      = "OFF",  // Enable debug port
	
	parameter SIMULATION = "OFF"
   )(
	input sys_clk_p,
	input sys_clk_n,
	input clk_ref_p,
	input clk_ref_n,
	input sys_rst,
	input sys_reset_n,
	// DDRx Output Interface
	output [CK_WIDTH-1:0]              ddr_ck_p,
	output [CK_WIDTH-1:0]              ddr_ck_n,
	output [ROW_WIDTH-1:0]             ddr_addr,
	output [BANK_WIDTH-1:0]            ddr_ba,
	output                             ddr_ras_n,
	output                             ddr_cas_n,
	output                             ddr_we_n,
	output [CS_WIDTH*nCS_PER_RANK-1:0] ddr_cs_n,
	output [CKE_WIDTH-1:0]             ddr_cke,
	output [CS_WIDTH*nCS_PER_RANK-1:0] ddr_odt,
	output                             ddr_reset_n,
	//output                             ddr_parity,
	output [DM_WIDTH-1:0]              ddr_dm,
	inout [DQS_WIDTH-1:0]              ddr_dqs_p,
	inout [DQS_WIDTH-1:0]              ddr_dqs_n,
	inout [DQ_WIDTH-1:0]               ddr_dq,

	output                             dfi_init_complete, //led 0
	output										processing_iseq, //led 1
	output 										iq_full, //led 2
	output 										rdback_fifo_empty, //led 3
	
	//PCIE
	
	`ifndef SIM //we dont want to simulate PCIe core
	
	output  [7:0]    pci_exp_txp,
	output  [7:0]    pci_exp_txn,
	input   [7:0]    pci_exp_rxp,
	input   [7:0]    pci_exp_rxn
  
	`else

	input  app_en,
	output app_ack,
	input[31:0] app_instr,

	//Data read back Interface
	//output rdback_fifo_empty,
	input rdback_fifo_rden,
	output[DQ_WIDTH*4 - 1:0] rdback_data

	`endif //SIM
    );
	 
	 assign ddr_dm = {DM_WIDTH{1'b0}};
	 
	 /*** CLOCK MANAGEMENT ***/
	 
	 localparam SYSCLK_PERIOD = tCK * nCK_PER_CLK;
	 localparam MMCM_ADV_BANDWIDTH = "OPTIMIZED";
	 
	 wire clk_mem, clk, clk_rd_base;
	 wire clk_ref = 0;
	 wire rst;
	 wire pd_PSDONE, pd_PSEN, pd_PSINCDEC; //phase detector interface
	 wire iodelay_ctrl_rdy;
	 wire mmcm_clk;
	 wire sys_clk = 0;
	 
	 //use 200MHZ refrence clock to generate mmcm_clk
	 iodelay_ctrl #
    (
     .TCQ            (TCQ),
     .IODELAY_GRP    (IODELAY_GRP),
     .INPUT_CLK_TYPE (INPUT_CLK_TYPE),
     .RST_ACT_LOW    (RST_ACT_LOW)
     )
    u_iodelay_ctrl
      (
       .clk_ref_p        (clk_ref_p), //input
       .clk_ref_n        (clk_ref_n), //input
       .clk_ref          (clk_ref), //input
       .sys_rst          (sys_rst), //input
		 .clk_200			(mmcm_clk),
       .iodelay_ctrl_rdy (iodelay_ctrl_rdy) //output
       );
		 
	 infrastructure #
    (
     .TCQ                (TCQ),
     .CLK_PERIOD         (SYSCLK_PERIOD),
     .nCK_PER_CLK        (nCK_PER_CLK),
     .MMCM_ADV_BANDWIDTH (MMCM_ADV_BANDWIDTH),
     .CLKFBOUT_MULT_F    (CLKFBOUT_MULT_F),
     .DIVCLK_DIVIDE      (DIVCLK_DIVIDE),
     .CLKOUT_DIVIDE      (CLKOUT_DIVIDE),
     .RST_ACT_LOW        (RST_ACT_LOW)
     )
    u_infrastructure
      (
       .clk_mem          (clk_mem), //output
       .clk              (clk), //output
       .clk_rd_base      (clk_rd_base), //output
       .rstdiv0          (rst), //output
		 
       .mmcm_clk         (mmcm_clk), //input
       .sys_rst          (sys_rst), //input
       .iodelay_ctrl_rdy (iodelay_ctrl_rdy), //input
       .PSDONE           (pd_PSDONE), //output
       .PSEN             (pd_PSEN), //input
       .PSINCDEC         (pd_PSINCDEC) //input
       );
		 
		 
   wire [ROW_WIDTH-1:0]              dfi_address0;
   wire [ROW_WIDTH-1:0]              dfi_address1;
   wire [BANK_WIDTH-1:0]             dfi_bank0;
   wire [BANK_WIDTH-1:0]             dfi_bank1;
   wire 										 dfi_cas_n0;
   wire 										 dfi_cas_n1;
   wire [CKE_WIDTH-1:0]              dfi_cke0;
   wire [CKE_WIDTH-1:0]              dfi_cke1;
   wire [CS_WIDTH*nCS_PER_RANK-1:0]  dfi_cs_n0;
   wire [CS_WIDTH*nCS_PER_RANK-1:0]  dfi_cs_n1;
   wire [CS_WIDTH*nCS_PER_RANK-1:0]  dfi_odt0;
   wire [CS_WIDTH*nCS_PER_RANK-1:0]  dfi_odt1;
   wire                              dfi_ras_n0;
   wire                              dfi_ras_n1;
   wire                              dfi_reset_n;
	assign dfi_reset_n = 1;
   wire                              dfi_we_n0;
   wire                              dfi_we_n1;
   // DFI Write
   wire                              dfi_wrdata_en;
   wire [4*DQ_WIDTH-1:0]             dfi_wrdata;
   wire [4*(DQ_WIDTH/8)-1:0]         dfi_wrdata_mask;
   // DFI Read
   wire                              dfi_rddata_en;
	wire 										 dfi_rddata_en_even;
	wire 										 dfi_rddata_en_odd;
   wire [4*DQ_WIDTH-1:0]             dfi_rddata;
   wire                              dfi_rddata_valid;
   wire                              dfi_rddata_valid_even;
   wire                              dfi_rddata_valid_odd;

   // DFI Initialization Status / CLK Disable
   wire                              dfi_dram_clk_disable;
   // sideband signals
   wire                              io_config_strobe;
   wire [RANK_WIDTH:0]               io_config;
	 
	 localparam CLK_PERIOD = tCK * nCK_PER_CLK;
	 phy_top  #(
     .TCQ                               (TCQ),
     .REFCLK_FREQ                       (REFCLK_FREQ),
     .nCS_PER_RANK                      (nCS_PER_RANK),
     .CAL_WIDTH                         (CAL_WIDTH),
     .CALIB_ROW_ADD                     (CALIB_ROW_ADD),
     .CALIB_COL_ADD                     (CALIB_COL_ADD),
     .CALIB_BA_ADD                      (CALIB_BA_ADD),
     .CS_WIDTH                          (CS_WIDTH),
     .nCK_PER_CLK                       (nCK_PER_CLK),
     .CKE_WIDTH                         (CKE_WIDTH),
     .DRAM_TYPE                         (DRAM_TYPE),
     .SLOT_0_CONFIG                     (SLOT_0_CONFIG),
     .SLOT_1_CONFIG                     (SLOT_1_CONFIG),
     .CLK_PERIOD                        (CLK_PERIOD),
     .BANK_WIDTH                        (BANK_WIDTH),
     .CK_WIDTH                          (CK_WIDTH),
     .COL_WIDTH                         (COL_WIDTH),
     .DM_WIDTH                          (DM_WIDTH),
     .DQ_CNT_WIDTH                      (DQ_CNT_WIDTH),
     .DQ_WIDTH                          (DQ_WIDTH),
     .DQS_CNT_WIDTH                     (DQS_CNT_WIDTH),
     .DQS_WIDTH                         (DQS_WIDTH),
     .DRAM_WIDTH                        (DRAM_WIDTH),
     .ROW_WIDTH                         (ROW_WIDTH),
     .RANK_WIDTH                        (RANK_WIDTH),
     .AL                                (AL),
     .BURST_MODE                        (BURST_MODE),
     .BURST_TYPE                        (BURST_TYPE),
     .nAL                               (nAL),
     .nCL                               (nCL),
     .nCWL                              (nCWL),
     .tRFC                              (tRFC),
     .OUTPUT_DRV                        (OUTPUT_DRV),
     .REG_CTRL                          (REG_CTRL),
     .RTT_NOM                           (RTT_NOM),
     .RTT_WR                            (RTT_WR),
     .WRLVL                             (WRLVL),
     .PHASE_DETECT                      (PHASE_DETECT),
     .IODELAY_HP_MODE                   (IODELAY_HP_MODE),
     .IODELAY_GRP                       (IODELAY_GRP),
     // Prevent the following simulation-related parameters from
     // being overridden for synthesis - for synthesis only the
     // default values of these parameters should be used
     // synthesis translate_off
     .SIM_BYPASS_INIT_CAL               (SIM_BYPASS_INIT_CAL),
	  .SIM_INIT_OPTION(SIM_INIT_OPTION),
	  .SIM_CAL_OPTION(SIM_CAL_OPTION),
	  
     // synthesis translate_on
     .nDQS_COL0                         (nDQS_COL0),
     .nDQS_COL1                         (nDQS_COL1),
     .nDQS_COL2                         (nDQS_COL2),
     .nDQS_COL3                         (nDQS_COL3),
     .DQS_LOC_COL0                      (DQS_LOC_COL0),
     .DQS_LOC_COL1                      (DQS_LOC_COL1),
     .DQS_LOC_COL2                      (DQS_LOC_COL2),
     .DQS_LOC_COL3                      (DQS_LOC_COL3),
     .USE_DM_PORT                       (USE_DM_PORT),
     .DEBUG_PORT                        (DEBUG_PORT)
   ) xil_phy (
    .clk_mem(clk_mem), //input
    .clk(clk), //input
    .clk_rd_base(clk_rd_base), //input
    .rst(rst), //input
    .slot_0_present(SLOT_0_CONFIG), //input
    .slot_1_present(SLOT_1_CONFIG), //input
	 
    .dfi_address0(dfi_address0), //Note: '0' versions are used for row commands, '1' versions for column commands
    .dfi_address1(dfi_address1), 
    .dfi_bank0(dfi_bank0), 
    .dfi_bank1(dfi_bank1), 
    .dfi_cas_n0(dfi_cas_n0), 
    .dfi_cas_n1(dfi_cas_n1), 
    .dfi_cke0(dfi_cke0), 
    .dfi_cke1(dfi_cke1), 
    .dfi_cs_n0(dfi_cs_n0), 
    .dfi_cs_n1(dfi_cs_n1), 
    .dfi_odt0(dfi_odt0), 
    .dfi_odt1(dfi_odt1), 
    .dfi_ras_n0(dfi_ras_n0), 
    .dfi_ras_n1(dfi_ras_n1), 
    .dfi_reset_n(dfi_reset_n), 
    .dfi_we_n0(dfi_we_n0), 
    .dfi_we_n1(dfi_we_n1), 
    .dfi_wrdata_en(dfi_wrdata_en), 
    .dfi_wrdata(dfi_wrdata), 
    .dfi_wrdata_mask(dfi_wrdata_mask), 
    .dfi_rddata_en(dfi_rddata_en), 
	 .dfi_rddata_en_even(dfi_rddata_en_even),
	 .dfi_rddata_en_odd(dfi_rddata_en_odd),
    .dfi_rddata(dfi_rddata), 
    .dfi_rddata_valid(dfi_rddata_valid), 
	 .dfi_rddata_valid_even(dfi_rddata_valid_even),
    .dfi_rddata_valid_odd(dfi_rddata_valid_odd), 
    .dfi_dram_clk_disable(dfi_dram_clk_disable), 
    .dfi_init_complete(dfi_init_complete), 
	 
	 //sideband signals
    .io_config_strobe(io_config_strobe), //input
    .io_config(io_config), //input [RANK_WIDTH:0]
	 
	 //DRAM signals
    .ddr_ck_p(ddr_ck_p), 
    .ddr_ck_n(ddr_ck_n), 
    .ddr_addr(ddr_addr), 
    .ddr_ba(ddr_ba), 
    .ddr_ras_n(ddr_ras_n), 
    .ddr_cas_n(ddr_cas_n), 
    .ddr_we_n(ddr_we_n), 
    .ddr_cs_n(ddr_cs_n), 
    .ddr_cke(ddr_cke), 
    .ddr_odt(ddr_odt), 
    .ddr_reset_n(ddr_reset_n), 
    //.ddr_parity(ddr_parity), 
    .ddr_dm(ddr_dm), 
    .ddr_dqs_p(ddr_dqs_p), 
    .ddr_dqs_n(ddr_dqs_n), 
    .ddr_dq(ddr_dq), 
	 
	 //phase detection signals
    .pd_PSDONE(pd_PSDONE), 
    .pd_PSEN(pd_PSEN), 
    .pd_PSINCDEC(pd_PSINCDEC)
    );
	 
	 //App Command Interface
	 `ifndef SIM
	wire app_en;
	wire app_ack;
	wire[31:0] app_instr;
	
	
	//Data read back Interface
	wire rdback_fifo_rden;
	wire[DQ_WIDTH*4 - 1:0] rdback_data;
	`endif //SIM
	
	
	 softMC #(.TCQ(TCQ), .tCK(tCK), .nCK_PER_CLK(nCK_PER_CLK), .RANK_WIDTH(RANK_WIDTH), .ROW_WIDTH(ROW_WIDTH), .BANK_WIDTH(BANK_WIDTH), 
								.CKE_WIDTH(CKE_WIDTH), .CS_WIDTH(CS_WIDTH), .nCS_PER_RANK(nCS_PER_RANK), .DQ_WIDTH(DQ_WIDTH)) i_softmc(
	.clk(clk),
	.rst(rst),
	
	//App Command Interface
	.app_en(app_en),
	.app_ack(app_ack),
	.app_instr(app_instr), 
	.iq_full(iq_full),
	.processing_iseq(processing_iseq),
	
	// DFI Control/Address
	.dfi_address0(dfi_address0),
	.dfi_address1(dfi_address1),
	.dfi_bank0(dfi_bank0),
	.dfi_bank1(dfi_bank1),
	.dfi_cas_n0(dfi_cas_n0),
	.dfi_cas_n1(dfi_cas_n1),
	.dfi_cke0(dfi_cke0),
	.dfi_cke1(dfi_cke1),
	.dfi_cs_n0(dfi_cs_n0),
	.dfi_cs_n1(dfi_cs_n1),
	.dfi_odt0(dfi_odt0),
	.dfi_odt1(dfi_odt1),
	.dfi_ras_n0(dfi_ras_n0),
	.dfi_ras_n1(dfi_ras_n1),
	.dfi_reset_n(dfi_reset_n),
	.dfi_we_n0(dfi_we_n0),
	.dfi_we_n1(dfi_we_n1),
	// DFI Write
	.dfi_wrdata_en(dfi_wrdata_en),
	.dfi_wrdata(dfi_wrdata),
	.dfi_wrdata_mask(dfi_wrdata_mask),
	// DFI Read
	.dfi_rddata_en(dfi_rddata_en),
	.dfi_rddata_en_even(dfi_rddata_en_even),
	.dfi_rddata_en_odd(dfi_rddata_en_odd),
	.dfi_rddata(dfi_rddata),
	.dfi_rddata_valid(dfi_rddata_valid),
	.dfi_rddata_valid_even(dfi_rddata_valid_even),
	.dfi_rddata_valid_odd(dfi_rddata_valid_odd),
	// DFI Initialization Status / CLK Disable
	.dfi_dram_clk_disable(dfi_dram_clk_disable),
	.dfi_init_complete(dfi_init_complete),
	// sideband signals
	.io_config_strobe(io_config_strobe),
	.io_config(io_config),
	
	//Data read back Interface
	.rdback_fifo_empty(rdback_fifo_empty),
	.rdback_fifo_rden(rdback_fifo_rden),
	.rdback_data(rdback_data)
);

`ifndef SIM

riffa_top_v6_pcie_v2_5 #(
  .C_DATA_WIDTH(64),            // RX/TX interface data width
  .DQ_WIDTH(DQ_WIDTH)
) i_pcie_top
(
  .pci_exp_txp(pci_exp_txp),
  .pci_exp_txn(pci_exp_txn),
  .pci_exp_rxp(pci_exp_rxp),
  .pci_exp_rxn(pci_exp_rxn),

  .sys_clk_p(sys_clk_p),
  .sys_clk_n(sys_clk_n),
  .sys_reset_n(sys_reset_n),
  
	.app_clk(clk),
	.app_en(app_en),
	.app_ack(app_ack),
	.app_instr(app_instr),
	
	//Data read back Interface
	.rdback_fifo_empty(rdback_fifo_empty),
	.rdback_fifo_rden(rdback_fifo_rden),
	.rdback_data(rdback_data)
);

`endif //SIM

endmodule
