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
	output [31:0] CHNL_TX_LEN, 
	output [30:0] CHNL_TX_OFF, 
	output [C_PCI_DATA_WIDTH-1:0] CHNL_TX_DATA, 
	output reg CHNL_TX_DATA_VALID, 
	input CHNL_TX_DATA_REN,
	
	output  app_en,
	input app_ack,
	output[31:0] app_instr,
	
	input process_iseq,
	
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
 
 localparam STATE_PENDING_ACK = 0;
 localparam STATE_ACKED = 1;
 reg state_rx_ack = STATE_PENDING_ACK;
 
 always@(posedge clk) begin
	
	case(state_rx_ack)
		STATE_PENDING_ACK: begin
			if(CHNL_RX) begin
				CHNL_RX_ACK <= 1'b1;
				state_rx_ack <= STATE_ACKED;
			end
		end
		STATE_ACKED: begin
			CHNL_RX_ACK <= 1'b0;
			
			if(process_iseq)
				state_rx_ack <= STATE_PENDING_ACK;
		end
	endcase
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


wire[DQ_WIDTH*4 - 1:0] data_to_send;
wire data_to_send_available;
reg data_to_send_consume;


pipe_reg #(.WIDTH(DQ_WIDTH*4)) i_rdback_fifo_preg(
        .clk(clk),
        .rst(rst),
		  
		  //producer interface
		  .valid_in(~rdback_fifo_empty),
        .data_in(rdback_data),
        .ready_out(rdback_fifo_rden),
		  
		  //consumer interface
        .ready_in(data_to_send_consume),
        .valid_out(data_to_send_available),
        .data_out(data_to_send)
    );

reg[2:0] sender_state = 0; //edit this if DQ_WIDTH or C_PCI_DATA_WIDTH changes
reg[2:0] sender_state_ns;

localparam SENDER_INIT_TX = 3'b100;
localparam SENDER_STEP1 = 3'b000;
localparam SENDER_END = 3'b011;

assign CHNL_TX_LEN = 2048; 

//NOTE: //seems like there is a bug (or an undocumented case) in RIFFA. 
//After completing a transaction, CHNL_TX_DATA_REN remains high for a few cycles. 
//We need to wait it to become LOW before initiating another transaction.

reg[6:0] idle_counter = 0, idle_counter_ns;
reg[7:0] sent_chunks_counter = 0, sent_chunks_counter_ns;

always@* begin
	data_to_send_consume = 1'b0;
	sender_state_ns = sender_state;
	idle_counter_ns = idle_counter;
	sent_chunks_counter_ns = sent_chunks_counter;
	CHNL_TX = 0;
	CHNL_TX_DATA_VALID = 0;
	
	case(sender_state)
		SENDER_INIT_TX: begin
			if(data_to_send_available & ~CHNL_TX_DATA_REN/*See the NOTE above*/) begin
				sender_state_ns = SENDER_STEP1;
				sent_chunks_counter_ns = 0;
			end
		end //SENDER_INIT_TX
		
		//Each loop from SENDER_STEP1 to SENDER_END sends sizeof(data_to_send) words
		SENDER_STEP1: begin //SENDER_IDLE
			CHNL_TX = 1;
			if(data_to_send_available) begin
				CHNL_TX_DATA_VALID = 1;
				idle_counter_ns = 0;
				if(CHNL_TX_DATA_REN)
					sender_state_ns = sender_state + 1;
			end
			else begin
				idle_counter_ns = idle_counter + 1;
				
				if(idle_counter == 7'd127) //end a transaction (even when CHNL_TX_LEN is not reached) when not receiving data to sent for 128 cycles
					sender_state_ns = SENDER_INIT_TX;
			end
		end // SENDER_STEP1
		
		SENDER_END: begin
			CHNL_TX = 1;
			CHNL_TX_DATA_VALID = 1;
			if(CHNL_TX_DATA_REN) begin
				sender_state_ns = SENDER_STEP1;
				data_to_send_consume = 1'b1;
				sent_chunks_counter_ns = sent_chunks_counter + 1;
				
				if(sent_chunks_counter == 8'd255)
					sender_state_ns = SENDER_INIT_TX;
			end
		end //SENDER_END
		
		default: begin
			CHNL_TX = 1'b1;
			CHNL_TX_DATA_VALID = 1'b1;
			if(CHNL_TX_DATA_REN) begin
				sender_state_ns = sender_state + 1;
			end
		end
		
	endcase
end

always@(posedge clk) begin
	if(rst) begin
		sender_state <= 0;
		idle_counter = 0;
		sent_chunks_counter = 0;
	end
	else begin
		sender_state <= sender_state_ns;
		idle_counter = idle_counter_ns;
		sent_chunks_counter = sent_chunks_counter_ns;
	end
end

wire[7:0] offset = {6'd0, sender_state[1:0]} << 6;
assign CHNL_TX_DATA = data_to_send[offset +: 64];

endmodule
