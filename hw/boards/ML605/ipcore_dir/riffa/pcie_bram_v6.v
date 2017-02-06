//-----------------------------------------------------------------------------
//
// (c) Copyright 2009-2011 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Virtex-6 Integrated Block for PCI Express
// File       : pcie_bram_v6.v
// Version    : 2.4
//--
//-- Description: BlockRAM module for Virtex6 PCIe Block
//--
//--
//--
//--------------------------------------------------------------------------------

`timescale 1ns/1ns

module pcie_bram_v6
  #(
    parameter DOB_REG = 0,// 1 use the output register 0 don't use the output register
    parameter WIDTH = 0   // supported WIDTH's are: 4, 9, 18, 36 (uses RAMB36) and 72 (uses RAMB36SDP)
    )
    (
     input               user_clk_i,// user clock
     input               reset_i,   // bram reset

     input               wen_i,     // write enable
     input [12:0]        waddr_i,   // write address
     input [WIDTH - 1:0] wdata_i,   // write data

     input               ren_i,     // read enable
     input               rce_i,     // output register clock enable
     input [12:0]        raddr_i,   // read address

     output [WIDTH - 1:0] rdata_o   // read data
     );

   // map the address bits
   localparam ADDR_MSB = ((WIDTH == 4)  ? 12 :
                          (WIDTH == 9)  ? 11 :
                          (WIDTH == 18) ? 10 :
                          (WIDTH == 36) ?  9 :
                                           8
                          );

   // set the width of the tied off low address bits
   localparam ADDR_LO_BITS = ((WIDTH == 4)  ? 2 :
                              (WIDTH == 9)  ? 3 :
                              (WIDTH == 18) ? 4 :
                              (WIDTH == 36) ? 5 :
                                              0 // for WIDTH 72 use RAMB36SDP
                              );

   // map the data bits
   localparam D_MSB =  ((WIDTH == 4)  ?  3 :
                        (WIDTH == 9)  ?  7 :
                        (WIDTH == 18) ? 15 :
                        (WIDTH == 36) ? 31 :
                                        63
                        );

   // map the data parity bits
   localparam DP_LSB =  D_MSB + 1;

   localparam DP_MSB =  ((WIDTH == 4)  ? 4 :
                         (WIDTH == 9)  ? 8 :
                         (WIDTH == 18) ? 17 :
                         (WIDTH == 36) ? 35 :
                                         71
                        );

   localparam DPW = DP_MSB - DP_LSB + 1;

   localparam WRITE_MODE = "NO_CHANGE";

   //synthesis translate_off
   initial begin
      //$display("[%t] %m DOB_REG %0d WIDTH %0d ADDR_MSB %0d ADDR_LO_BITS %0d DP_MSB %0d DP_LSB %0d D_MSB %0d",
      //          $time, DOB_REG,   WIDTH,    ADDR_MSB,    ADDR_LO_BITS,    DP_MSB,    DP_LSB,    D_MSB);

      case (WIDTH)
        4,9,18,36,72:;
        default:
          begin
             $display("[%t] %m Error WIDTH %0d not supported", $time, WIDTH);
             $finish;
          end
      endcase // case (WIDTH)
   end
   //synthesis translate_on

   generate
   if (WIDTH == 72) begin : use_ramb36sdp

      // use RAMB36SDP if the width is 72
      RAMB36SDP #(
               .DO_REG        (DOB_REG)
               )
        ramb36sdp(
               .WRCLK          (user_clk_i),
               .SSR            (1'b0),
               .WRADDR         (waddr_i[ADDR_MSB:0]),
               .DI             (wdata_i[D_MSB:0]),
               .DIP            (wdata_i[DP_MSB:DP_LSB]),
               .WREN           (wen_i),
               .WE             ({8{wen_i}}),
               .DBITERR        (),
               .ECCPARITY      (),
               .SBITERR        (),

               .RDCLK          (user_clk_i),
               .RDADDR         (raddr_i[ADDR_MSB:0]),
               .DO             (rdata_o[D_MSB:0]),
               .DOP            (rdata_o[DP_MSB:DP_LSB]),
               .RDEN           (ren_i),
               .REGCE          (rce_i)
               );

    // use RAMB36's if the width is 4, 9, 18, or 36
    end else if (WIDTH == 36) begin : use_ramb36

      RAMB36 #(
               .DOA_REG       (0),
               .DOB_REG       (DOB_REG),
               .READ_WIDTH_A  (0),
               .READ_WIDTH_B  (WIDTH),
               .WRITE_WIDTH_A (WIDTH),
               .WRITE_WIDTH_B (0),
               .WRITE_MODE_A  (WRITE_MODE)
               )
        ramb36(
               .CLKA           (user_clk_i),
               .SSRA           (1'b0),
               .REGCEA         (1'b0),
               .CASCADEINLATA  (1'b0),
               .CASCADEINREGA  (1'b0),
               .CASCADEOUTLATA (),
               .CASCADEOUTREGA (),
               .DOA            (),
               .DOPA           (),
               .ADDRA          ({1'b1, waddr_i[ADDR_MSB:0], {ADDR_LO_BITS{1'b1}}}),
               .DIA            (wdata_i[D_MSB:0]),
               .DIPA           (wdata_i[DP_MSB:DP_LSB]),
               .ENA            (wen_i),
               .WEA            ({4{wen_i}}),

               .CLKB           (user_clk_i),
               .SSRB           (1'b0),
               .WEB            (4'b0),
               .CASCADEINLATB  (1'b0),
               .CASCADEINREGB  (1'b0),
               .CASCADEOUTLATB (),
               .CASCADEOUTREGB (),
               .DIB            (32'b0),
               .DIPB           ( 4'b0),
               .ADDRB          ({1'b1, raddr_i[ADDR_MSB:0], {ADDR_LO_BITS{1'b1}}}),
               .DOB            (rdata_o[D_MSB:0]),
               .DOPB           (rdata_o[DP_MSB:DP_LSB]),
               .ENB            (ren_i),
               .REGCEB         (rce_i)
               );

   end else if (WIDTH < 36 && WIDTH > 4) begin : use_ramb36

      wire [31 - D_MSB - 1 : 0] dob_unused;
      wire [ 4 - DPW   - 1 : 0] dopb_unused;

      RAMB36 #(
               .DOA_REG       (0),
               .DOB_REG       (DOB_REG),
               .READ_WIDTH_A  (0),
               .READ_WIDTH_B  (WIDTH),
               .WRITE_WIDTH_A (WIDTH),
               .WRITE_WIDTH_B (0),
               .WRITE_MODE_A  (WRITE_MODE)
               )
        ramb36(
               .CLKA           (user_clk_i),
               .SSRA           (1'b0),
               .REGCEA         (1'b0),
               .CASCADEINLATA  (1'b0),
               .CASCADEINREGA  (1'b0),
               .CASCADEOUTLATA (),
               .CASCADEOUTREGA (),
               .DOA            (),
               .DOPA           (),
               .ADDRA          ({1'b1, waddr_i[ADDR_MSB:0], {ADDR_LO_BITS{1'b1}}}),
               .DIA            ({{31 - D_MSB{1'b0}},wdata_i[D_MSB:0]}),
               .DIPA           ({{ 4 - DPW  {1'b0}},wdata_i[DP_MSB:DP_LSB]}),
               .ENA            (wen_i),
               .WEA            ({4{wen_i}}),

               .CLKB           (user_clk_i),
               .SSRB           (1'b0),
               .WEB            (4'b0),
               .CASCADEINLATB  (1'b0),
               .CASCADEINREGB  (1'b0),
               .CASCADEOUTLATB (),
               .CASCADEOUTREGB (),
               .DIB            (32'b0),
               .DIPB           ( 4'b0),
               .ADDRB          ({1'b1, raddr_i[ADDR_MSB:0], {ADDR_LO_BITS{1'b1}}}),
               .DOB            ({dob_unused,  rdata_o[D_MSB:0]}),
               .DOPB           ({dopb_unused, rdata_o[DP_MSB:DP_LSB]}),
               .ENB            (ren_i),
               .REGCEB         (rce_i)
               );

   end else if (WIDTH ==  4) begin : use_ramb36

      wire [31 - D_MSB - 1 : 0] dob_unused;

      RAMB36 #(
               .DOB_REG       (DOB_REG),
               .READ_WIDTH_A  (0),
               .READ_WIDTH_B  (WIDTH),
               .WRITE_WIDTH_A (WIDTH),
               .WRITE_WIDTH_B (0),
               .WRITE_MODE_A  (WRITE_MODE)
               )
        ramb36(
               .CLKA           (user_clk_i),
               .SSRA           (1'b0),
               .REGCEA         (1'b0),
               .CASCADEINLATA  (1'b0),
               .CASCADEINREGA  (1'b0),
               .CASCADEOUTLATA (),
               .CASCADEOUTREGA (),
               .DOA            (),
               .DOPA           (),
               .ADDRA          ({1'b1, waddr_i[ADDR_MSB:0], {ADDR_LO_BITS{1'b1}}}),
               .DIA            ({{31 - D_MSB{1'b0}},wdata_i[D_MSB:0]}),
               //.DIPA           (wdata_i[DP_MSB:DP_LSB]),
               .ENA            (wen_i),
               .WEA            ({4{wen_i}}),

               .CLKB           (user_clk_i),
               .SSRB           (1'b0),
               .WEB            (4'b0),
               .CASCADEINLATB  (1'b0),
               .CASCADEINREGB  (1'b0),
               .CASCADEOUTLATB (),
               .CASCADEOUTREGB (),
               .ADDRB          ({1'b1, raddr_i[ADDR_MSB:0], {ADDR_LO_BITS{1'b1}}}),
               .DOB            ({dob_unused,rdata_o[D_MSB:0]}),
               //.DOPB           (rdata_o[DP_MSB:DP_LSB]),
               .ENB            (ren_i),
               .REGCEB         (rce_i)
               );

   end // block: use_ramb36
   endgenerate

endmodule // pcie_bram_v6
