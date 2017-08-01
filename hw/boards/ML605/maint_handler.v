`timescale 1ps / 1ps

`include "softMC.inc"

module maint_handler #(parameter CS_WIDTH = 1)(
			input clk,
			input rst,
			
			input pr_rd_req,
			input zq_req,
			input autoref_req,
			input[1:0] cur_bus_dir,
			
			output maint_instr_en,
			input maint_ack,
			output reg[31:0] maint_instr,
			
			input pr_rd_ack, //comes from the instruction sequence (iseq) dispatcher
			output reg zq_ack,
			output reg autoref_ack,
			
			output periodic_read_lock,
			
			input[27:0] trfc
    );
	 
	 localparam HIGH = 1'b1;
	 localparam LOW = 1'b0;
	 
	 //maintenance logic
	 reg pr_rd_process_ns, pr_rd_process_r = 1'b0;
    reg zq_process_ns, zq_process_r = 1'b0;
	 reg autoref_process_ns, autoref_process_r = 1'b0;
	 wire maint_process;
	 
	 localparam PR_RD_IO = 4'b0000;
	 localparam PR_RD_PRE = 4'b0001;
	 localparam PR_RD_WAIT_PRE = 4'b0010;
	 localparam PR_RD_ACT = 4'b0011;
	 localparam PR_RD_WAIT_ACT = 4'b0100;
	 localparam PR_RD_READ = 4'b0101;
	 localparam PR_RD_WAIT_READ = 4'b0110;
	 localparam PR_RD_PRE2 = 4'b0111;
	 localparam PR_RD_WAIT_PRE2 = 4'b1000;
	 localparam PR_RD_WR_IO = 4'b1001;
	 localparam MAINT_FIN = 4'b1010;
	 
	 localparam ZQ_PRE = 4'b0000;
	 localparam ZQ_WAIT_PRE = 4'b0001;
	 localparam ZQ_ZQ = 4'b0010;
	 localparam ZQ_WAIT_ZQ = 4'b0011;
	 
	 localparam AREF_PRE = 4'b0000;
	 localparam AREF_WAIT_PRE = 4'b0001;
	 localparam AREF_REF = 4'b0010;
	 localparam AREF_WAIT_REF = 4'b0011;
	 
	 reg[3:0] maint_state, maint_state_ns;
	 
	 reg lock_pr_rd_r, lock_pr_rd_ns;
	 reg[1:0] cur_bus_dir_r, cur_bus_dir_ns;
	 
	 always@* begin
		pr_rd_process_ns = pr_rd_process_r;
		zq_process_ns = zq_process_r;
		autoref_process_ns = autoref_process_r;
		
		lock_pr_rd_ns = lock_pr_rd_r;
		
		zq_ack = 1'b0;
		autoref_ack = 1'b0;
		
		maint_state_ns = maint_state;
		maint_instr = {`END_ISEQ, 28'd0};
		
		cur_bus_dir_ns = cur_bus_dir_r;
			
		//enter maintenance
		if(~maint_process) begin
			if(pr_rd_req & ~lock_pr_rd_r) begin
				pr_rd_process_ns = 1'b1;
				maint_state_ns = PR_RD_IO;
			end //pr_rd_req
			else if(zq_req) begin
				zq_process_ns = 1'b1;
				maint_state_ns = ZQ_PRE;
			end //zq_req
			else if(autoref_req) begin
				autoref_process_ns = 1'b1;
				maint_state_ns = AREF_PRE;
			end
		end //~dispatcher_busy_r
		
		//process maintenance
		if(maint_process) begin
			if(pr_rd_process_r) begin //TODO: optimize to reduce periodic dummy read latency when open bank is available
				case(maint_state)
					PR_RD_IO: begin
						maint_instr[31:28] = `SET_BUSDIR;
						
						cur_bus_dir_ns = cur_bus_dir;
						
						if(maint_ack)
							maint_state_ns = PR_RD_PRE;
					end //PR_RD_IO
					
					PR_RD_PRE: begin
					
						//Precharge banks 0
						maint_instr[31:28] = `DDR_INSTR;
						maint_instr[`CKE_OFFSET] = HIGH;
						maint_instr[`CS_OFFSET +: CS_WIDTH] = {{CS_WIDTH-1{HIGH}}, LOW};
						maint_instr[`RAS_OFFSET] = LOW;
						maint_instr[`CAS_OFFSET] = HIGH;
						maint_instr[`WE_OFFSET] = LOW;
						maint_instr[10] = LOW; //10th bit of the address field, A[10]
						
						if(maint_ack)
							maint_state_ns = PR_RD_WAIT_PRE;
					end
					
					PR_RD_WAIT_PRE: begin
						maint_instr[31:28] = `WAIT;
						maint_instr[27:0] = `DEF_TRP;
						
						if(maint_ack)
							maint_state_ns = PR_RD_ACT;
					end //PR_RD_WAIT_PRE
					
					PR_RD_ACT: begin
						//activate bank 0, row 0
						maint_instr[31:28] = `DDR_INSTR;
						maint_instr[`CKE_OFFSET] = HIGH;
						maint_instr[`CS_OFFSET +: CS_WIDTH] = {{CS_WIDTH-1{HIGH}}, LOW};
						maint_instr[`RAS_OFFSET] = LOW;
						maint_instr[`CAS_OFFSET] = HIGH;
						maint_instr[`WE_OFFSET] = HIGH;
						
						if(maint_ack)
							maint_state_ns = PR_RD_WAIT_ACT;
					end //PR_RD_ACT
					
					PR_RD_WAIT_ACT: begin
						maint_instr[31:28] = `WAIT;
						maint_instr[27:0] = `DEF_TRCD;
						
						if(maint_ack)
							maint_state_ns = PR_RD_READ;
					end //PR_RD_WAIT_ACT
					
					PR_RD_READ: begin
					
						//Read instruction
						maint_instr[31:28] = `DDR_INSTR;
						maint_instr[`CKE_OFFSET] = HIGH;
						maint_instr[`CS_OFFSET +: CS_WIDTH] = {{CS_WIDTH-1{HIGH}}, LOW};
						maint_instr[`RAS_OFFSET] = HIGH;
						maint_instr[`CAS_OFFSET] = LOW;
						maint_instr[`WE_OFFSET] = HIGH;
						
						if(maint_ack)
							maint_state_ns = PR_RD_WAIT_READ;
					end //PR_RD_READ
					
					PR_RD_WAIT_READ: begin
						maint_instr[31:28] = `WAIT;
						maint_instr[27:0] = `DEF_TRAS - `DEF_TRCD;
						
						if(maint_ack)
							maint_state_ns = PR_RD_PRE2;
					end //PR_RD_WAIT_READ
					
					PR_RD_PRE2: begin
						//Precharge banks 0
						maint_instr[31:28] = `DDR_INSTR;
						maint_instr[`CKE_OFFSET] = HIGH;
						maint_instr[`CS_OFFSET +: CS_WIDTH] = {{CS_WIDTH-1{HIGH}}, LOW};
						maint_instr[`RAS_OFFSET] = LOW;
						maint_instr[`CAS_OFFSET] = HIGH;
						maint_instr[`WE_OFFSET] = LOW;
						maint_instr[10] = LOW; //10th bit of the address field, A[10]
						
						if(maint_ack)
							maint_state_ns = PR_RD_WAIT_PRE2;
					end //PR_RD_PRE2
					
					PR_RD_WAIT_PRE2: begin
						maint_instr[31:28] = `WAIT;
						maint_instr[27:0] = `DEF_TRP;
						
						if(maint_ack)
							maint_state_ns = (cur_bus_dir_r == `BUS_DIR_READ) ? MAINT_FIN : PR_RD_WR_IO;
					end //PR_RD_WAIT_PRE2
					
					PR_RD_WR_IO: begin
						maint_instr[31:28] = `SET_BUSDIR;
						maint_instr[1:0] = `BUS_DIR_WRITE;
						
						if(maint_ack)
							maint_state_ns = MAINT_FIN;
					end
					
					MAINT_FIN: begin
						maint_instr[31:28] = `END_ISEQ;
						pr_rd_process_ns = 1'b0;
						lock_pr_rd_ns = 1'b1;
					end //MAINT_FIN
					
				endcase //pr_rd_state
			end //pr_rd_process_r
			else if(zq_process_r) begin
				case(maint_state)
					ZQ_PRE: begin
						//Precharge all banks
						maint_instr[31:28] = `DDR_INSTR;
						maint_instr[`CKE_OFFSET] = HIGH;
						maint_instr[`CS_OFFSET +: CS_WIDTH] = {{CS_WIDTH-1{HIGH}}, LOW};
						maint_instr[`RAS_OFFSET] = LOW;
						maint_instr[`CAS_OFFSET] = HIGH;
						maint_instr[`WE_OFFSET] = LOW;
						maint_instr[10] = HIGH; //10th bit of the address field, A[10]
						
						if(maint_ack)
							maint_state_ns = ZQ_WAIT_PRE;
					end //ZQ_INIT	
					
					ZQ_WAIT_PRE: begin
						maint_instr[31:28] = `WAIT;
						maint_instr[27:0] = `DEF_TRP;
						
						if(maint_ack)
							maint_state_ns = ZQ_ZQ;
					end //ZQ_WAIT_PRE
					
					ZQ_ZQ: begin
						//ZQ-Short Instruction
						maint_instr[31:28] = `DDR_INSTR;
						maint_instr[`CKE_OFFSET] = HIGH;
						maint_instr[`CS_OFFSET +: CS_WIDTH] = {{CS_WIDTH-1{HIGH}}, LOW};
						maint_instr[`RAS_OFFSET] = HIGH;
						maint_instr[`CAS_OFFSET] = HIGH;
						maint_instr[`WE_OFFSET] = LOW;
						maint_instr[10] = LOW; //10th bit of the address field, A[10]
						
						if(maint_ack)
							maint_state_ns = ZQ_WAIT_ZQ;
					end //ZQ_ZQ
					
					ZQ_WAIT_ZQ: begin
						maint_instr[31:28] = `WAIT;
						maint_instr[27:0] = `DEF_TZQCS;
						
						if(maint_ack)
							maint_state_ns = MAINT_FIN;
					end //ZQ_WAIT_ZQ
					
					MAINT_FIN: begin
						maint_instr[31:28] = `END_ISEQ;
						zq_process_ns = 1'b0;
						zq_ack = 1'b1;
					end //MAINT_FIN
				
				endcase //maint_state
			end //zq_process_r
			
			else if(autoref_process_r) begin
				case(maint_state)
					AREF_PRE: begin
						//Precharge all banks
						maint_instr[31:28] = `DDR_INSTR;
						maint_instr[`CKE_OFFSET] = HIGH;
						maint_instr[`CS_OFFSET +: CS_WIDTH] = {{CS_WIDTH-1{HIGH}}, LOW};
						maint_instr[`RAS_OFFSET] = LOW;
						maint_instr[`CAS_OFFSET] = HIGH;
						maint_instr[`WE_OFFSET] = LOW;
						maint_instr[10] = HIGH; //10th bit of the address field, A[10]
						
						if(maint_ack)
							maint_state_ns = AREF_WAIT_PRE;
					end //AREF_PRE
					
					AREF_WAIT_PRE: begin
						maint_instr[31:28] = `WAIT;
						maint_instr[27:0] = `DEF_TRP;
						
						if(maint_ack)
							maint_state_ns = AREF_REF;
					end //AREF_WAIT_PRE
					
					AREF_REF: begin
						//Refresh Instruction //TODO: assign CS appropriately when implementing multi-rank support
						maint_instr[31:28] = `DDR_INSTR;
						maint_instr[`CKE_OFFSET] = HIGH;
						maint_instr[`CS_OFFSET +: CS_WIDTH] = {{CS_WIDTH-1{HIGH}}, LOW};
						maint_instr[`RAS_OFFSET] = LOW;
						maint_instr[`CAS_OFFSET] = LOW;
						maint_instr[`WE_OFFSET] = HIGH;
						maint_instr[10] = HIGH; //10th bit of the address field, A[10]
						
						if(maint_ack)
							maint_state_ns = AREF_WAIT_REF;
					end //AREF_REF
					
					AREF_WAIT_REF: begin
						maint_instr[31:28] = `WAIT;
						maint_instr[27:0] = trfc;
						
						if(maint_ack)
							maint_state_ns = MAINT_FIN;
					end //AREF_WAIT_REF
					
					MAINT_FIN: begin
						maint_instr[31:28] = `END_ISEQ;
						autoref_process_ns = 1'b0;
						autoref_ack = 1'b1;
					end //MAINT_FIN
					
				endcase //maint_state
			end //autoref_process_r
			
		end //maint_process
		
		if(pr_rd_ack) begin
			lock_pr_rd_ns = 1'b0;
			pr_rd_process_ns = 1'b0;
		end
			
    end //always maintenance
	 
	 assign periodic_read_lock = lock_pr_rd_r;
	 
	 always@(posedge clk) begin
		if(rst) begin
			lock_pr_rd_r <= 1'b0;
			maint_state <= 4'd0;
			cur_bus_dir_r <= `BUS_DIR_READ;
		end
		else begin
			lock_pr_rd_r <= lock_pr_rd_ns;
			maint_state <= maint_state_ns;
			cur_bus_dir_r <= cur_bus_dir_ns;
		end
	 end
	 
	 assign maint_process = pr_rd_process_r | zq_process_r | autoref_process_r;
	 
	 assign maint_instr_en = maint_process;
		
	 always@(posedge clk) begin
		pr_rd_process_r <= pr_rd_process_ns;
		zq_process_r <= zq_process_ns;
		autoref_process_r <= autoref_process_ns;
	 end


endmodule
