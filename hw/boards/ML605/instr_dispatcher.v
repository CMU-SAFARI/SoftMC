`timescale 1ns / 1ps

`include "softMC.inc"

module instr_dispatcher #(parameter ROW_WIDTH = 15, BANK_WIDTH = 3, CKE_WIDTH = 1, RANK_WIDTH = 1,
										CS_WIDTH = 1, nCS_PER_RANK = 1, DQ_WIDTH = 64) (
	input clk,
	input rst,
	
	input periodic_read_lock,
	
	//There are two instructions queues to fetch from. Since PHY issues DDR commands at both pos and neg edges, 
	//we dispatch two instructions in the same cycle, running at half of the frequency of the DDR bus
	input en_in0,
	output en_ack0,
	input[31:0] instr_in0,
	
	input en_in1,
	output en_ack1,
	input[31:0] instr_in1,
	
	//DFI Interface
	// DFI Control/Address
	input 											dfi_ready,
	output[ROW_WIDTH-1:0]              dfi_address0,
	output[ROW_WIDTH-1:0]              dfi_address1,
	output[BANK_WIDTH-1:0]             dfi_bank0,
	output[BANK_WIDTH-1:0]             dfi_bank1,
	output									  dfi_cke0,
	output 									  dfi_cke1,
	output									  dfi_cas_n0,
	output										dfi_cas_n1,
	output[CS_WIDTH*nCS_PER_RANK-1:0]  dfi_cs_n0,
	output[CS_WIDTH*nCS_PER_RANK-1:0]  dfi_cs_n1,
	output[CS_WIDTH*nCS_PER_RANK-1:0]  dfi_odt0,
	output[CS_WIDTH*nCS_PER_RANK-1:0]  dfi_odt1,
	output										dfi_ras_n0,
	output										dfi_ras_n1,
	output										dfi_we_n0,
	output										dfi_we_n1,
	// DFI Write
	output reg                             dfi_wrdata_en,
	output [4*DQ_WIDTH-1:0]             dfi_wrdata,
	output [4*(DQ_WIDTH/8)-1:0]         dfi_wrdata_mask,
	// DFI Read
	output reg                             dfi_rddata_en,
	output reg										dfi_rddata_en_even,
	output reg 										dfi_rddata_en_odd,
	
	//Bus Command
	output reg io_config_strobe,
	output reg[1:0] io_config,
	
	//Misc.
	output pr_rd_ack,
	
	//auto-refresh
   output reg aref_set_interval,
   output reg[27:0] aref_interval, 
   output reg aref_set_trfc,
   output reg[27:0] aref_trfc
);
	
	localparam ONE = 1;
	localparam TWO = 2;
	
	localparam HIGH = 1'b1;
	localparam LOW = 1'b0;
	
	reg[9:0] wait_cycles_r = ONE[0 +: 10], wait_cycles_ns;
	
	reg read_burst_r, read_burst_ns;
	reg read_burst_even_r, read_burst_even_ns;
	reg read_burst_odd_r, read_burst_odd_ns;
	reg write_burst_r, write_burst_ns;
	reg[7:0] write_burst_data_r, write_burst_data_ns;
	
	reg bus_write, bus_write_r;
	
	reg pr_rd_ack_r, pr_rd_ack_ns;
	
	reg ack0, ack1;
	reg instr_src_r, instr_src_ns;
	
	reg dec0_en;
	wire[31:0] dec0_instr;
	
	reg dec1_en;
	wire[31:0] dec1_instr;
	
	wire en0 = instr_src_r ? en_in1 : en_in0;
	wire[31:0] instr0 = instr_src_r ? instr_in1 : instr_in0;
	assign en_ack0 = instr_src_r ? ack1 : ack0;
	
	wire en1 = instr_src_r ? en_in0 : en_in1;
	wire[31:0] instr1 = instr_src_r ? instr_in0 : instr_in1;
	assign en_ack1 = instr_src_r ? ack0 : ack1;
	
	assign dec0_instr = instr0;
	assign dec1_instr = instr1;
	
	reg block_other_slot;
	
	reg cke0, cke0_r, cke1, cke1_r;
	
	//auto-refresh
	reg aref_set_interval_ns, aref_set_trfc_ns;
	reg[27:0] aref_interval_ns, aref_trfc_ns;
	
	//Counter saturating at zero
	reg load_counter;
	always@(posedge clk) begin
		if(rst)
			wait_cycles_r <= 10'd0;
		else begin
			if(load_counter) begin
				wait_cycles_r <= wait_cycles_ns;
			end //load_counter
			else begin
				if(|wait_cycles_r[9:1])
					wait_cycles_r <= wait_cycles_r - TWO[0 +: 10];
				else
					wait_cycles_r <= 10'd0;
			end
		end
	end
	
	always@* begin
		io_config_strobe = LOW;
		io_config = 2'b00;
		bus_write = bus_write_r;
		
		instr_src_ns = ~(en_in0 | en_in1) ? LOW : instr_src_r;
		
		ack0 = HIGH;
		ack1 = HIGH;
		
		dec0_en = LOW;
		dec1_en = LOW;
		
		read_burst_ns = LOW;
		read_burst_even_ns = LOW;
		read_burst_odd_ns = LOW;
		write_burst_ns = LOW;
		write_burst_data_ns = write_burst_data_r;
		
		dfi_rddata_en = read_burst_r;
		dfi_rddata_en_even = read_burst_even_r;
		dfi_rddata_en_odd = read_burst_odd_r;
		dfi_wrdata_en = write_burst_r;
		
		pr_rd_ack_ns = LOW;
		
		aref_set_interval_ns = 1'b0;
		aref_interval_ns = {28{1'bx}};
		aref_set_trfc_ns = 1'b0;
		aref_trfc_ns = {28{1'bx}};
		
		wait_cycles_ns = 10'dx;
		load_counter = LOW;
		
		block_other_slot = LOW;
		
		cke0 = cke0_r;
		cke1 = cke1_r;
		
		if(dfi_ready & (wait_cycles_r <= 10'd1)) begin
			if(en0) begin
				casex(instr0[31:28])
					`SET_BUSDIR: begin
						io_config_strobe = HIGH;
						io_config = instr0[1:0];
						
						if(instr0[1:0] == `BUS_DIR_WRITE)
							bus_write = 1'b1;
						else
							bus_write = 1'b0;
					end //SET_BUSDIR
					
					`DDR_INSTR: begin
						dec0_en = HIGH;
						cke0 = instr0[`CKE_OFFSET];
						
						if(~|instr0[`CS_OFFSET +: CS_WIDTH] && instr0[`RAS_OFFSET] && ~instr0[`CAS_OFFSET] &&
									instr0[`WE_OFFSET] && cke0 && cke0_r) begin //check whether we have a read instruction
							dfi_rddata_en = HIGH;
							dfi_rddata_en_even = HIGH;
							read_burst_ns = HIGH;
							read_burst_even_ns = HIGH;
							
							dfi_rddata_en_odd = periodic_read_lock; //to indicate periodic read response
							read_burst_odd_ns = periodic_read_lock;
							
							pr_rd_ack_ns = HIGH;
						end
						
						if(~|instr0[`CS_OFFSET +: CS_WIDTH] && instr0[`RAS_OFFSET] && ~instr0[`CAS_OFFSET] &&
									~instr0[`WE_OFFSET] && cke0 && cke0_r) begin //check whether we have a write instruction
							dfi_wrdata_en = HIGH;
							write_burst_ns = HIGH;
							
							write_burst_data_ns = {instr0[30:25], instr0[(`ROW_OFFSET - 1) -:2]};
							end
					end //DDR_INSTR
					
					`WAIT: begin
						load_counter = HIGH;
						wait_cycles_ns = instr0[9:0] - 10'd1; //reducing by one for the second slot
						
						if(instr0[9:0] > 10'd1)
							block_other_slot = HIGH;
						
						if(~instr0[0])
							instr_src_ns = ~instr_src_r;
					end //WAIT
					
					`SET_TREFI: begin
						aref_set_interval_ns = 1'b1;
						aref_interval_ns = instr0[27:0];
					end //SET_TREFI
					
					`SET_TRFC: begin
						aref_set_trfc_ns = 1'b1;
						aref_trfc_ns = instr0[27:0];
					end //SET_TRFC
				
				endcase //instr0
			end //en0
		end
		else begin
			ack0 = LOW;
		end
		
		if(~(en0 & block_other_slot) & dfi_ready & (wait_cycles_r <= 10'd2)) begin
			if(en1) begin
				casex(instr1[31:28])
					`SET_BUSDIR: begin
						io_config_strobe = HIGH;
						io_config = instr1[1:0];
						
						if(instr1[1:0] == `BUS_DIR_WRITE)
							bus_write = 1'b1;
						else
							bus_write = 1'b0;
					end //SET_BUSDIR
					
					`DDR_INSTR: begin
						dec1_en = HIGH;
						cke1 = instr1[`CKE_OFFSET];
						
						if(~|instr1[`CS_OFFSET +: CS_WIDTH] && instr1[`RAS_OFFSET] && ~instr1[`CAS_OFFSET] &&
									instr1[`WE_OFFSET] && cke1 && cke1_r) begin //check whether we have a read command
							dfi_rddata_en = HIGH;
							read_burst_ns = HIGH;
							
							dfi_rddata_en_odd = periodic_read_lock; //to indicate periodic read response
							read_burst_odd_ns = periodic_read_lock;
							
							pr_rd_ack_ns = HIGH;
						end
						
						if(~|instr1[`CS_OFFSET +: CS_WIDTH] && instr1[`RAS_OFFSET] && ~instr1[`CAS_OFFSET] &&
									~instr1[`WE_OFFSET] && cke1 && cke1_r) begin //check whether we have a write command
							dfi_wrdata_en = HIGH;
							write_burst_ns = HIGH;
							
							write_burst_data_ns = {instr1[30:25], instr1[(`ROW_OFFSET - 1) -:2]};
							end
					end //DDR_INSTR
					
					`WAIT: begin
						wait_cycles_ns = instr1[9:0];
						load_counter = HIGH;
						
						if(~instr1[0])
							instr_src_ns = ~instr_src_r;
					end //WAIT
					
					`SET_TREFI: begin
						aref_set_interval_ns = 1'b1;
						aref_interval_ns = instr1[27:0];
					end //SET_TREFI
					
					`SET_TRFC: begin
						aref_set_trfc_ns = 1'b1;
						aref_trfc_ns = instr1[27:0];
					end //SET_TRFC
					
				endcase //instr1
			end //en1
		end
		else begin
			ack1 = LOW;
		end
	end
	
	instr_decoder #(.ROW_WIDTH(ROW_WIDTH), .BANK_WIDTH(BANK_WIDTH), .CS_WIDTH(CS_WIDTH)) instr_dec0(
		.en(dec0_en),
		.instr(dec0_instr),
		
		.dfi_address(dfi_address0),
		.dfi_bank(dfi_bank0),
		.dfi_cas_n(dfi_cas_n0),
		.dfi_cs_n(dfi_cs_n0),
		.dfi_ras_n(dfi_ras_n0),
		.dfi_we_n(dfi_we_n0)
	);
	
	instr_decoder #(.ROW_WIDTH(ROW_WIDTH), .BANK_WIDTH(BANK_WIDTH), .CS_WIDTH(CS_WIDTH)) i_instr_dec1(
		.en(dec1_en),
		.instr(dec1_instr),
		
		.dfi_address(dfi_address1),
		.dfi_bank(dfi_bank1),
		.dfi_cas_n(dfi_cas_n1),
		.dfi_cs_n(dfi_cs_n1),
		.dfi_ras_n(dfi_ras_n1),
		.dfi_we_n(dfi_we_n1)
	);
	
	assign dfi_wrdata_mask = 0;
	assign dfi_wrdata = dfi_cas_n0 ? {4*(DQ_WIDTH/8){write_burst_data_r}} : {4*(DQ_WIDTH/8){write_burst_data_ns}};
	
	always@(posedge clk) begin
		pr_rd_ack_r <= pr_rd_ack_ns;
	end
	assign pr_rd_ack = pr_rd_ack_r;
	
	always@(posedge clk) begin
		if(rst) begin
			aref_set_interval <= 0;
			aref_set_trfc <= 0;
			aref_interval <= 0;
			aref_trfc <= 0;
			
			cke0_r <= 1'b1; //not sure what would happen if the clock is disabled on reset
			cke1_r <= 1'b1;
		end
		else begin
			aref_set_interval <= aref_set_interval_ns;
			aref_set_trfc <= aref_set_trfc_ns;
			aref_interval <= aref_interval_ns;
			aref_trfc <= aref_trfc_ns;
			
			cke0_r <= cke0;
			cke1_r <= cke1;
		end
	end
	
	
	always@(posedge clk) begin
		if(rst) begin
			read_burst_r <= LOW;
			read_burst_even_r <= LOW;
			read_burst_odd_r <= LOW;
			write_burst_r <= LOW;
			write_burst_data_r <= 0;
			
			bus_write_r <= LOW;
			
			instr_src_r <= LOW;
		end
		else begin
			read_burst_r <= read_burst_ns;
			read_burst_even_r <= read_burst_even_ns;
			read_burst_odd_r <= read_burst_odd_ns;
			write_burst_r <= write_burst_ns;
			write_burst_data_r <= write_burst_data_ns;
			
			bus_write_r <= bus_write;
			
			instr_src_r <= instr_src_ns;
		end //!rst
	end
	
	assign dfi_odt0 = bus_write_r;
	assign dfi_odt1 = bus_write_r;
	
	assign dfi_cke0 = cke0_r;
	assign dfi_cke1 = cke1_r;
endmodule
