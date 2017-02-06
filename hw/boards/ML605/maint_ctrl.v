`timescale 1ps / 1ps
//Hasan

module maint_ctrl_top #(parameter RANK_WIDTH = 1, TCQ = 100, tCK = 2500, nCK_PER_CLK = 2, MAINT_PRESCALER_PERIOD = 200000) (
    input clk,
	 input rst,
	 
	 input dfi_init_complete,
	 
	 input periodic_rd_ack,
	 output periodic_rd_req,
	 input zq_ack,
	 output zq_req,
	 
	 //Auto-refresh
	 input autoref_en,
	 input[27:0] autoref_interval,
	 input autoref_ack,
	 output autoref_req
    );
	 
	 /*** MAINTENANCE CONTROLLER ***/
	 wire maint_prescaler_tick;
	 maint_ctrl #(.TCQ(TCQ), .tCK(tCK), .nCK_PER_CLK(nCK_PER_CLK), .MAINT_PRESCALER_PERIOD(MAINT_PRESCALER_PERIOD)) i_maint_ctrl(
		.clk(clk),
		.rst(rst),
	
		.dfi_init_complete(dfi_init_complete),
	
		.maint_prescaler_tick(maint_prescaler_tick)
	);
	 
	 
	 /*** PERIODIC READ CONTROLLER ***/
	 periodic_rd_ctrl #(.tCK(tCK), .nCK_PER_CLK(nCK_PER_CLK), .TCQ(TCQ), .MAINT_PRESCALER_PERIOD(MAINT_PRESCALER_PERIOD)) i_prrd_ctrl(
		.clk(clk),
		.rst(rst),
		
		.maint_prescaler_tick(maint_prescaler_tick),
		.dfi_init_complete(dfi_init_complete),
		
		.periodic_rd_ack(periodic_rd_ack),
		.periodic_rd_req(periodic_rd_req)
	);
	 
	 /*** ZQ CALIBRATION CONTROLLER ***/
	 zq_calib_ctrl #(.TCQ(TCQ), .MAINT_PRESCALER_PERIOD(MAINT_PRESCALER_PERIOD)) i_zq_calib_ctrl(
		.clk(clk),
		.rst(rst),
		
		.maint_prescaler_tick(maint_prescaler_tick),
		.dfi_init_complete(dfi_init_complete),
		
		.zq_ack(zq_ack),
		.zq_request(zq_req)
	);
	
	autoref_ctrl #(.TCQ(TCQ)) i_autoref_ctrl (
		.clk(clk),
		.rst(rst),
		
		.autoref_en(autoref_en),
		.autoref_interval(autoref_interval),
		.maint_prescaler_tick(maint_prescaler_tick),
		.dfi_init_complete(dfi_init_complete),
		
		.autoref_ack(autoref_ack),
		.autoref_req(autoref_req)
	);

endmodule

module maint_ctrl #(parameter TCQ = 100, tCK = 2500, nCK_PER_CLK = 2, MAINT_PRESCALER_PERIOD = 200000) (
	input clk,
	input rst,
	
	input dfi_init_complete,
	
	output maint_prescaler_tick
);

	function integer clogb2 (input integer size); // ceiling logb2
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
            size = size >> 1;
    end
	endfunction // clogb2
	
   localparam MAINT_PRESCALER_DIV = MAINT_PRESCALER_PERIOD/(tCK * nCK_PER_CLK);  // Round down.
	localparam MAINT_PRESCALER_WIDTH = clogb2(MAINT_PRESCALER_DIV + 1);
	localparam ONE = 1;
	
	// Maintenance and periodic read prescaler.  Nominally 200 nS.
	reg maint_prescaler_tick_r_lcl;
	reg [MAINT_PRESCALER_WIDTH-1:0] maint_prescaler_r;
	reg [MAINT_PRESCALER_WIDTH-1:0] maint_prescaler_ns;
	
	wire maint_prescaler_tick_ns = (maint_prescaler_r == ONE[MAINT_PRESCALER_WIDTH-1:0]);
	always @(/*AS*/dfi_init_complete or maint_prescaler_r
				or maint_prescaler_tick_ns) begin
		maint_prescaler_ns = maint_prescaler_r;
		if (~dfi_init_complete || maint_prescaler_tick_ns)
			maint_prescaler_ns = MAINT_PRESCALER_DIV[MAINT_PRESCALER_WIDTH-1:0];
		else if (|maint_prescaler_r)
			maint_prescaler_ns = maint_prescaler_r - ONE[MAINT_PRESCALER_WIDTH-1:0];
	end
	
	always @(posedge clk) maint_prescaler_r <= #TCQ maint_prescaler_ns;

	always @(posedge clk) maint_prescaler_tick_r_lcl <= #TCQ maint_prescaler_tick_ns;
								  
	assign maint_prescaler_tick = maint_prescaler_tick_r_lcl;

endmodule

//NOTE: this module is designed for 1 rank systems

module periodic_rd_ctrl #(parameter tCK = 2500, nCK_PER_CLK = 2, TCQ = 100, MAINT_PRESCALER_PERIOD = 200000) (
		input clk,
		input rst,
		
		input dfi_init_complete,
		input maint_prescaler_tick,
		
		input periodic_rd_ack, //NOTE: this also should be asserted for regular reads
		output periodic_rd_req
	);
	
	function integer clogb2 (input integer size); // ceiling logb2
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
            size = size >> 1;
    end
	endfunction // clogb2
	
	localparam tPRDI = 1_000_000;
	localparam PERIODIC_RD_TIMER_DIV = tPRDI/MAINT_PRESCALER_PERIOD;
	localparam PERIODIC_RD_TIMER_WIDTH = clogb2(PERIODIC_RD_TIMER_DIV + /*idle state*/ 1);
	localparam ONE = 1;
	 
	reg [PERIODIC_RD_TIMER_WIDTH-1:0] periodic_rd_timer_r, periodic_rd_timer;
	reg periodic_rd_request_r;
	 
	always @* begin
		periodic_rd_timer = periodic_rd_timer_r;
		
		if(~dfi_init_complete) begin
			periodic_rd_timer = {PERIODIC_RD_TIMER_WIDTH{1'b0}};
		end
		else if (periodic_rd_ack) begin
			periodic_rd_timer = PERIODIC_RD_TIMER_DIV[0+:PERIODIC_RD_TIMER_WIDTH];
		end
		else if (|periodic_rd_timer_r && maint_prescaler_tick) begin
			periodic_rd_timer = periodic_rd_timer_r - ONE[0+:PERIODIC_RD_TIMER_WIDTH];
		end
	end //always
	 
	wire periodic_rd_timer_one = maint_prescaler_tick && (periodic_rd_timer_r == ONE[0+:PERIODIC_RD_TIMER_WIDTH]);
	 
	wire periodic_rd_request = ~rst && (/*((PERIODIC_RD_TIMER_DIV != 0) && ~dfi_init_complete) ||*/
                      (~periodic_rd_ack && (periodic_rd_request_r || periodic_rd_timer_one)));
	 
	always @(posedge clk) begin
		periodic_rd_timer_r <= #TCQ periodic_rd_timer;
		periodic_rd_request_r <= #TCQ periodic_rd_request;
	end //always
	
	assign periodic_rd_req = periodic_rd_request_r;
	
endmodule


module zq_calib_ctrl #(parameter TCQ = 100, MAINT_PRESCALER_PERIOD = 200000) (
	input clk,
	input rst,
	
	input zq_ack,
	output reg zq_request,
	
	input dfi_init_complete,
	input maint_prescaler_tick
);

	function integer clogb2 (input integer size); // ceiling logb2
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
            size = size >> 1;
    end
	endfunction // clogb2

	// ZQ timebase.  Nominally 128 mS
	localparam MAINT_PRESCALER_PERIOD_NS = MAINT_PRESCALER_PERIOD / 1000;
	localparam tZQI = 128_000_000;
	localparam ZQ_TIMER_DIV = tZQI/MAINT_PRESCALER_PERIOD_NS;
	localparam ZQ_TIMER_WIDTH = clogb2(ZQ_TIMER_DIV + 1);
	localparam ONE = 1;
	
	generate
		begin : zq_cntrl
			reg zq_tick = 1'b0;
			
			if (ZQ_TIMER_DIV !=0) begin : zq_timer
				reg [ZQ_TIMER_WIDTH-1:0] zq_timer_r;
				reg [ZQ_TIMER_WIDTH-1:0] zq_timer_ns;
				
				always @(/*AS*/dfi_init_complete or maint_prescaler_tick
				or zq_tick or zq_timer_r) begin
					zq_timer_ns = zq_timer_r;
					if (~dfi_init_complete || zq_tick)
						zq_timer_ns = ZQ_TIMER_DIV[ZQ_TIMER_WIDTH-1:0];
					else if (|zq_timer_r && maint_prescaler_tick)
						zq_timer_ns = zq_timer_r - ONE[ZQ_TIMER_WIDTH-1:0];
				end
				
				always @(posedge clk) zq_timer_r <= #TCQ zq_timer_ns;
				
				always @(/*AS*/maint_prescaler_tick or zq_timer_r)
					zq_tick = (zq_timer_r == ONE[ZQ_TIMER_WIDTH-1:0] && maint_prescaler_tick);
			end // zq_timer

			// ZQ request. Set request with timer tick, and when exiting PHY init.  Never
			// request if ZQ_TIMER_DIV == 0.
			begin : zq_request_logic
				wire zq_clears_zq_request = zq_ack;
				reg zq_request_r;
				wire zq_request_ns = ~rst && ((~dfi_init_complete && (ZQ_TIMER_DIV != 0)) || 
					(zq_request_r && ~zq_clears_zq_request) || zq_tick);
				
				always @(posedge clk) zq_request_r <= #TCQ zq_request_ns;
				
				always @(/*AS*/dfi_init_complete or zq_request_r)
					zq_request = dfi_init_complete && zq_request_r;
			end // zq_request_logic
		end
	endgenerate

endmodule

module autoref_ctrl #(parameter TCQ = 100) (
	input clk,
	input rst,
	
	input autoref_en,
	input[27:0] autoref_interval,
	input autoref_ack,
	output autoref_req,
	
	input dfi_init_complete,
	input maint_prescaler_tick
);

	localparam ONE = 1;
	 
	reg [27:0] autoref_timer_r, autoref_timer;
	reg autoref_request_r;
	reg ref_en_r;
	 
	always @* begin
		autoref_timer = autoref_timer_r;
		
		if(~dfi_init_complete || autoref_ack || (~ref_en_r && autoref_en)) begin
			autoref_timer = autoref_interval;
		end
		else if (|autoref_timer_r && maint_prescaler_tick) begin
			autoref_timer = autoref_timer_r - ONE[0+:28];
		end
	end //always
	 
	wire autoref_timer_one = maint_prescaler_tick && (autoref_timer_r == ONE[0+:28]);
	 
	wire autoref_request = ~rst && dfi_init_complete && autoref_en && (
								(~autoref_ack && (autoref_request_r || autoref_timer_one)));
	 
	always @(posedge clk) begin
		autoref_timer_r <= #TCQ autoref_timer;
		autoref_request_r <= #TCQ autoref_request;
		ref_en_r <= #TCQ autoref_en;
	end //always
	
	assign autoref_req = autoref_request_r;

endmodule
