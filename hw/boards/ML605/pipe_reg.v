`timescale 1ps / 1ps

module pipe_reg #(parameter WIDTH = 8) (
        input clk,
        input rst,
        
        input ready_in,
        input valid_in,
        input[WIDTH - 1:0] data_in,
        output valid_out,
        output[WIDTH - 1:0] data_out,
        output ready_out
    );
    
    (* keep = "true" *) reg r_ready, r_valid1, r_valid2;
    (* keep = "true" *) reg[WIDTH - 1:0] r_data1, r_data2;
    
    wire first_buf_ready = ready_in | ~r_valid1;
    
    assign data_out = r_data1;
    assign valid_out = r_valid1;
    assign ready_out = r_ready;
    
    always@(posedge clk)
    begin
        if(rst) begin
            r_data1 <= 0;
            r_data2 <= 0;
            r_ready <= 0;
            r_valid1 <= 0;
            r_valid2 <= 0;
        end
        else begin
            //data acquisition
            if(r_ready) begin
                if(first_buf_ready) begin
                    r_data1 <= data_in;
                    r_valid1 <= valid_in;
                end
                else begin
                    r_data2 <= data_in;
                    r_valid2 <= valid_in;
                end
            end //r_ready
            
            //data shift
            if(~r_ready & ready_in) begin
                r_data1 <= r_data2;
                r_valid1 <= r_valid2;
            end
        end
        
        //control
        r_ready <= first_buf_ready;
    end
endmodule
