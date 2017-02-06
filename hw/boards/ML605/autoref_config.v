`timescale 1ns / 1ps
//Hasan

module autoref_config(
		input clk,
		input rst,
		
		input set_interval,
		input[27:0] interval_in,
		input set_trfc,
		input[27:0] trfc_in,
		
		
		output reg aref_en,
		output reg[27:0] aref_interval,
		output reg[27:0] trfc
    );
	 
	 
	 always@(posedge clk) begin
		if(rst) begin
			aref_en <= 0;
			aref_interval <= 0;
			trfc <= 0;
		end
		else begin
			if(set_interval) begin
				aref_en <= |interval_in;
				aref_interval <= interval_in;
			end //set_interval
			
			if(set_trfc) begin
				trfc <= trfc_in;
			end
		end
	 end

endmodule
