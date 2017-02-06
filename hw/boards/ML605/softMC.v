`timescale 1ps / 1ps

`include "softMC.inc"

//NOTE: currently accepts only one instruction sequence, need to process it first to receive another
module softMC #(parameter TCQ = 100, tCK = 2500, nCK_PER_CLK = 2, RANK_WIDTH = 1, ROW_WIDTH = 15, BANK_WIDTH = 3, 
								CKE_WIDTH = 1, CS_WIDTH = 1, nCS_PER_RANK = 1, DQ_WIDTH = 64) (
	input clk,
	input rst,
	
	//App Command Interface
	input app_en,
	output app_ack,
	input[31:0] app_instr, 
	output iq_full,
	output processing_iseq,
	
	// DFI Control/Address
	output [ROW_WIDTH-1:0]              dfi_address0,
	output [ROW_WIDTH-1:0]              dfi_address1,
	output [BANK_WIDTH-1:0]             dfi_bank0,
	output [BANK_WIDTH-1:0]             dfi_bank1,
	output 										dfi_cas_n0,
	output 										dfi_cas_n1,
	output [CKE_WIDTH-1:0]              dfi_cke0,
	output [CKE_WIDTH-1:0]              dfi_cke1,
	output [CS_WIDTH*nCS_PER_RANK-1:0]  dfi_cs_n0,
	output [CS_WIDTH*nCS_PER_RANK-1:0]  dfi_cs_n1,
	output [CS_WIDTH*nCS_PER_RANK-1:0]  dfi_odt0,
	output [CS_WIDTH*nCS_PER_RANK-1:0]  dfi_odt1,
	output 										dfi_ras_n0,
	output 										dfi_ras_n1,
	output 										dfi_reset_n,
	output 										dfi_we_n0,
	output 										dfi_we_n1,
	// DFI Write
	output                              dfi_wrdata_en,
	output [4*DQ_WIDTH-1:0]             dfi_wrdata,
	output [4*(DQ_WIDTH/8)-1:0]         dfi_wrdata_mask,
	// DFI Read
	output                              dfi_rddata_en,
	output										dfi_rddata_en_even,
	output										dfi_rddata_en_odd,
	input  [4*DQ_WIDTH-1:0]             dfi_rddata,
	input                               dfi_rddata_valid,
	input											dfi_rddata_valid_even,
	input											dfi_rddata_valid_odd,
	// DFI Initialization Status / CLK Disable
	output                              dfi_dram_clk_disable,
	input                               dfi_init_complete,
	// sideband signals
	output                              io_config_strobe,
	output [RANK_WIDTH:0]               io_config,
	
	//Data read back Interface
	output rdback_fifo_empty,
	input rdback_fifo_rden,
	output[DQ_WIDTH*4 - 1:0] rdback_data
);
	 
	 //DFI constants
	 assign dfi_reset_n = 1;
	 
	 wire instr0_fifo_en, instr0_fifo_full, instr0_fifo_empty;
	 wire[31:0] instr0_fifo_data, instr0_fifo_out;
	 wire instr0_fifo_rd_en;
	 
	 wire instr1_fifo_en, instr1_fifo_full, instr1_fifo_empty;
	 wire[31:0] instr1_fifo_data, instr1_fifo_out;
	 wire instr1_fifo_rd_en;
	 
	 wire process_iseq;
	 
	 //MAINTENANCE module
	 localparam MAINT_PRESCALER_PERIOD = 200000;
	 wire pr_rd_req, zq_req, autoref_req;
	 wire pr_rd_ack, zq_ack, autoref_ack;
	 
	 //Auto-refresh signals
	 wire aref_en;
	 wire[27:0] aref_interval;
	 wire[27:0] aref_trfc;
	 wire aref_set_interval, aref_set_trfc;
	 wire[27:0] aref_interval_in;
	 wire[27:0] aref_trfc_in;
	
	 maint_ctrl_top #(.RANK_WIDTH(RANK_WIDTH), .TCQ (TCQ), .tCK(tCK), 
							.nCK_PER_CLK(nCK_PER_CLK), .MAINT_PRESCALER_PERIOD(MAINT_PRESCALER_PERIOD)) 
	 i_maint_ctrl(
	  .clk(clk),
	  .rst(rst),
	
	  .dfi_init_complete(dfi_init_complete),
 	
 	  .periodic_rd_ack(pr_rd_ack),
	  .periodic_rd_req(pr_rd_req),
	  .zq_ack(zq_ack),
	  .zq_req(zq_req),
	  
	  //Auto-refresh
	  .autoref_en(aref_en),
	  .autoref_interval(aref_interval),
	  .autoref_ack(autoref_ack),
	  .autoref_req(autoref_req)
    );
	 
	 wire periodic_read_lock;
	 wire maint_en;
	 wire maint_ack;
	 wire[31:0] maint_instr;
	 
	 maint_handler #(.CS_WIDTH(CS_WIDTH)) i_maint_handler(
			.clk(clk),
			.rst(rst),
			
			.pr_rd_req(pr_rd_req),
			.zq_req(zq_req),
			.autoref_req(autoref_req),
			.cur_bus_dir(dfi_odt0 ? `BUS_DIR_WRITE : `BUS_DIR_READ),
			
			.maint_instr_en(maint_en),
			.maint_ack(maint_ack),
			.maint_instr(maint_instr),
			
			.pr_rd_ack(pr_rd_ack), //comes from the transaction dispatcher
			.zq_ack(zq_ack),
			.autoref_ack(autoref_ack),
			.periodic_read_lock(periodic_read_lock),
			
			.trfc(aref_trfc)
    );
	 
	 autoref_config i_aref_config(
		.clk(clk),
		.rst(rst),
		
		.set_interval(aref_set_interval),
		.interval_in(aref_interval_in),
		.set_trfc(aref_set_trfc),
		.trfc_in(aref_trfc_in),
		
		
		.aref_en(aref_en),
		.aref_interval(aref_interval),
		.trfc(aref_trfc)
	 );
	 
	 instr_receiver i_instr_recv(
		.clk(clk),
		.rst(rst),
		
		.dispatcher_ready(~dispatcher_busy),
		
		.app_en(app_en),
		.app_ack(app_ack),
		.app_instr(app_instr), 
		
		.maint_en(maint_en),
		.maint_ack(maint_ack),
		.maint_instr(maint_instr),
		
		.instr0_fifo_en(instr0_fifo_en),
		.instr0_fifo_data(instr0_fifo_data),
		
		.instr1_fifo_en(instr1_fifo_en),
		.instr1_fifo_data(instr1_fifo_data),
		
		.process_iseq(process_iseq)
	);
	
	instr_fifo i_instr0_fifo (
	  .srst(rst), // input rst
	  .clk(clk), // input clk
	  .din(instr0_fifo_data), // input [31 : 0] din
	  .wr_en(instr0_fifo_en), // input wr_en
	  .rd_en(instr0_fifo_rd_en), // input rd_en
	  .dout(instr0_fifo_out), // output [31 : 0] dout
	  .full(instr0_fifo_full), // output full
	  .empty(instr0_fifo_empty) // output empty
	);
	
	instr_fifo i_instr1_fifo (
	  .srst(rst), // input rst
	  .clk(clk), // input clk
	  .din(instr1_fifo_data), // input [31 : 0] din
	  .wr_en(instr1_fifo_en), // input wr_en
	  .rd_en(instr1_fifo_rd_en), // input rd_en
	  .dout(instr1_fifo_out), // output [31 : 0] dout
	  .full(instr1_fifo_full), // output full
	  .empty(instr1_fifo_empty) // output empty
	);
	
	
	wire dfi_ready;
	iseq_dispatcher #(.ROW_WIDTH(ROW_WIDTH), .BANK_WIDTH(BANK_WIDTH), .CKE_WIDTH(CKE_WIDTH), 
										.CS_WIDTH(CS_WIDTH), .nCS_PER_RANK(nCS_PER_RANK), .DQ_WIDTH(DQ_WIDTH)) i_iseq_disp (
    .clk(clk), 
    .rst(rst), 
	 
	 .periodic_read_lock(periodic_read_lock),
	 
    .process_iseq(process_iseq), 
    .dispatcher_busy(dispatcher_busy), 
	 
    .instr0_fifo_rd(instr0_fifo_rd_en), 
    .instr0_fifo_empty(instr0_fifo_empty), 
    .instr0_fifo_data(instr0_fifo_out), 

	 .instr1_fifo_rd(instr1_fifo_rd_en), 
    .instr1_fifo_empty(instr1_fifo_empty), 
    .instr1_fifo_data(instr1_fifo_out), 
	 
	 //DFI Interface
	 .dfi_ready(dfi_ready),
	 .dfi_init_complete(dfi_init_complete),
    .dfi_address0(dfi_address0), 
    .dfi_address1(dfi_address1), 
    .dfi_bank0(dfi_bank0), 
    .dfi_bank1(dfi_bank1), 
	 .dfi_cke0(dfi_cke0),
	 .dfi_cke1(dfi_cke1),
    .dfi_cas_n0(dfi_cas_n0), 
    .dfi_cas_n1(dfi_cas_n1), 
    .dfi_cs_n0(dfi_cs_n0), 
    .dfi_cs_n1(dfi_cs_n1),
	 .dfi_odt0(dfi_odt0),
	 .dfi_odt1(dfi_odt1),
    .dfi_ras_n0(dfi_ras_n0), 
    .dfi_ras_n1(dfi_ras_n1), 
    .dfi_we_n0(dfi_we_n0), 
    .dfi_we_n1(dfi_we_n1), 
    .dfi_wrdata_en(dfi_wrdata_en), 
    .dfi_wrdata(dfi_wrdata), 
    .dfi_wrdata_mask(dfi_wrdata_mask), 
    .dfi_rddata_en(dfi_rddata_en), 
	 .dfi_rddata_en_even(dfi_rddata_en_even),
	 .dfi_rddata_en_odd(dfi_rddata_en_odd),
    .io_config_strobe(io_config_strobe), 
    .io_config(io_config),
	 
	 .pr_rd_ack(pr_rd_ack),
	 
	 //auto-refresh
	 .aref_set_interval(aref_set_interval),
	 .aref_interval(aref_interval_in),
	 .aref_set_trfc(aref_set_trfc),
	 .aref_trfc(aref_trfc_in)
    );
	
	
	assign iq_full = instr0_fifo_full | instr1_fifo_full;
	assign processing_iseq = dispatcher_busy;
	
	wire[DQ_WIDTH*4 - 1: 0] rdback_fifo_wrdata, rdback_fifo_out;
	wire rdback_fifo_full, rdback_fifo_almost_full;
	wire rdback_fifo_wren;
	
	rdback_fifo i_rdback_fifo (
	  .clk(clk), // input clk
	  .srst(rst), // input srst
	  .din(rdback_fifo_wrdata), // input [255 : 0] din
	  .wr_en(rdback_fifo_wren), // input wr_en
	  .rd_en(rdback_fifo_rden), // input rd_en
	  .dout(rdback_fifo_out), // output [255 : 0] dout
	  .full(rdback_fifo_full), // output full
	  .almost_full(rdback_fifo_almost_full),
	  .empty(rdback_fifo_empty) // output empty
	);
	assign rdback_data = rdback_fifo_out;

	wire read_capturer_dfi_clk_disable;
	read_capturer #(.DQ_WIDTH(DQ_WIDTH)) i_rd_capturer (
	.clk(clk),
	.rst(rst),
	
	//DFI Interface
	.dfi_rddata(dfi_rddata),
	.dfi_rddata_valid(dfi_rddata_valid),
	.dfi_rddata_valid_even(dfi_rddata_valid_even),
	.dfi_rddata_valid_odd(dfi_rddata_valid_odd),
	.dfi_clk_disable(read_capturer_dfi_clk_disable),
	
	//FIFO interface
	.rdback_fifo_full(rdback_fifo_full),
	.rdback_fifo_almost_full(rdback_fifo_almost_full),
	.rdback_fifo_wren(rdback_fifo_wren),
	.rdback_fifo_wrdata(rdback_fifo_wrdata)
);

	assign dfi_dram_clk_disable = read_capturer_dfi_clk_disable;
	assign dfi_ready = ~dfi_dram_clk_disable;

endmodule