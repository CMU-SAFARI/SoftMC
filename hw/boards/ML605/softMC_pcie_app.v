`timescale 1ns / 1ps

module softMC_pcie_app #(
	parameter C_PCI_DATA_WIDTH = 9'd32, DQ_WIDTH = 64
)(
	input clk,
	input rst,
	output CHNL_RX_CLK, 
	input CHNL_RX, 
	output reg CHNL_RX_ACK, 
	input CHNL_RX_LAST, 
	input [31:0] CHNL_RX_LEN, 
	input [30:0] CHNL_RX_OFF, 
	input [C_PCI_DATA_WIDTH-1:0] CHNL_RX_DATA, 
	input CHNL_RX_DATA_VALID, 
	output CHNL_RX_DATA_REN,
	
	output CHNL_TX_CLK, 
	output reg CHNL_TX, 
	input CHNL_TX_ACK, 
	output CHNL_TX_LAST, 
	output reg [31:0] CHNL_TX_LEN, 
	output [30:0] CHNL_TX_OFF, 
	output [C_PCI_DATA_WIDTH-1:0] CHNL_TX_DATA, 
	output reg CHNL_TX_DATA_VALID, 
	input CHNL_TX_DATA_REN,
	
	output  app_en,
	input app_ack,
	output[31:0] app_instr,
	
	//Data read back Interface
	input rdback_fifo_empty,
	output rdback_fifo_rden,
	input[DQ_WIDTH*4 - 1:0] rdback_data
 );
 
 assign CHNL_RX_CLK = clk;
 assign CHNL_TX_CLK = clk;
 assign CHNL_TX_OFF = 0;
 assign CHNL_TX_LAST = 1'd1;
 
 reg app_en_r;
 reg[C_PCI_DATA_WIDTH-1:0] rx_data_r;
 
 reg old_chnl_rx;
 reg pending_ack = 0;
 
 //always acknowledge transaction
 always@(posedge clk) begin
		old_chnl_rx <= CHNL_RX;
		
		if(~old_chnl_rx & CHNL_RX)
			pending_ack <= 1'b1;
		
		if(CHNL_RX_ACK)
			CHNL_RX_ACK <= 1'b0;
		else begin
			if(pending_ack /*& app_ack*/) begin
				CHNL_RX_ACK <= 1'b1;
				pending_ack <= 1'b0;
			end
		end
 end
 
 //register incoming data
 assign CHNL_RX_DATA_REN = ~app_en_r | app_ack;
 always@(posedge clk) begin
	if(~app_en_r | app_ack) begin
		app_en_r <= CHNL_RX_DATA_VALID;
		rx_data_r <= CHNL_RX_DATA;
	end
 end
 
//send to the MC
assign app_en = app_en_r;
assign app_instr = rx_data_r;

//SEND DATA TO HOST
localparam RECV_IDLE = 1'b0;
localparam RECV_BUSY = 1'b1;

reg sender_ack;
reg[DQ_WIDTH*4 - 1:0] send_data_r;

reg recv_state = RECV_IDLE;
assign rdback_fifo_rden = (recv_state == RECV_IDLE);
always@(posedge clk) begin
	if(rst) begin
		recv_state <= RECV_IDLE;
	end
	else begin
		case(recv_state)
			RECV_IDLE: begin
				if(~rdback_fifo_empty) begin
					send_data_r <= rdback_data;
					recv_state <= RECV_BUSY;
				end
			end //RECV_IDLE
			
			RECV_BUSY: begin
				if(sender_ack)
					recv_state <= RECV_IDLE;
			end //RECV_BUSY
		endcase
	end
end

reg[2:0] sender_state = 0; //edit this if DQ_WIDTH or C_PCI_DATA_WIDTH changes
reg[2:0] sender_state_ns;

always@* begin
	sender_ack = 1'b0;
	sender_state_ns = sender_state;
	CHNL_TX = sender_state[2];
	
	CHNL_TX_LEN = 16;
	
	if(recv_state == RECV_BUSY) begin
		CHNL_TX = 1'b1;
		CHNL_TX_DATA_VALID = 1'b1;
		
		if(CHNL_TX_DATA_REN) begin
			sender_state_ns = sender_state + 3'd1;
			
			if(sender_state[1:0] == 2'b11)
				sender_ack = 1'b1;
		end
	end
end

always@(posedge clk) begin
	if(rst) begin
		sender_state <= 0;
	end
	else begin
		sender_state <= sender_state_ns;
	end
end

wire[7:0] offset = {6'd0, sender_state[1:0]} << 6;
assign CHNL_TX_DATA = send_data_r[offset +: 64];

endmodule
