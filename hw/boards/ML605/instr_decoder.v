`timescale 1ns / 1ps

`include "softMC.inc"

module instr_decoder #(parameter ROW_WIDTH = 15, BANK_WIDTH = 3, CS_WIDTH = 1)(
	input en,
	input[31:0] instr,
	
	output reg[ROW_WIDTH - 1:0] dfi_address,
	output reg[BANK_WIDTH - 1:0] dfi_bank,
	output reg dfi_cas_n,
	output reg[CS_WIDTH - 1:0] dfi_cs_n,
	output reg dfi_ras_n,
	output reg dfi_we_n
);
	
	localparam LOW = 1'b0;
	localparam HIGH = 1'b1;

	always@* begin
		dfi_address = {ROW_WIDTH{1'bx}};
		dfi_bank = {BANK_WIDTH{1'bx}};
		
		dfi_cas_n = HIGH;
		dfi_cs_n = {CS_WIDTH{HIGH}};
		dfi_ras_n = HIGH;
		dfi_we_n = HIGH;
		
		if(en) begin
			dfi_address = instr[ROW_WIDTH - 1:0];
			dfi_bank = instr[`ROW_OFFSET +: BANK_WIDTH];
			dfi_we_n = instr[`WE_OFFSET];
			dfi_cas_n = instr[`CAS_OFFSET];
			dfi_ras_n = instr[`RAS_OFFSET];
			dfi_cs_n = instr[`CS_OFFSET +: CS_WIDTH];
		end //en
	end
endmodule
