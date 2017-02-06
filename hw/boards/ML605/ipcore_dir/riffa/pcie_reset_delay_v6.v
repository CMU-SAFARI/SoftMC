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
// File       : pcie_reset_delay_v6.v
// Version    : 2.4
//--
//-- Description: sys_reset_n delay (20ms) for Virtex6 PCIe Block
//--
//--
//--
//--------------------------------------------------------------------------------

`timescale 1ns/1ns

module pcie_reset_delay_v6 # (

  parameter PL_FAST_TRAIN = "FALSE",
  parameter REF_CLK_FREQ = 0,   // 0 - 100 MHz, 1 - 125 MHz, 2 - 250 MHz
  parameter TCQ = 1

)
(

  input  wire        ref_clk,
  input  wire        sys_reset_n,
  output             delayed_sys_reset_n
   
);


  localparam         TBIT =  (PL_FAST_TRAIN == "FALSE") ?  ((REF_CLK_FREQ == 1) ? 20: (REF_CLK_FREQ == 0) ? 20 : 21) : 2;

  reg [7:0]          reg_count_7_0;
  reg [7:0]          reg_count_15_8;
  reg [7:0]          reg_count_23_16;
  wire [23:0]        concat_count;

  assign concat_count = {reg_count_23_16, reg_count_15_8, reg_count_7_0};

  always @(posedge ref_clk or negedge sys_reset_n) begin

    if (!sys_reset_n) begin

      reg_count_7_0 <= #TCQ 8'h0;
      reg_count_15_8 <= #TCQ 8'h0;
      reg_count_23_16 <= #TCQ 8'h0;

    end else begin

      if (delayed_sys_reset_n != 1'b1) begin

        reg_count_7_0   <= #TCQ reg_count_7_0 + 1'b1;
        reg_count_15_8  <= #TCQ (reg_count_7_0 == 8'hff)? reg_count_15_8  + 1'b1 : reg_count_15_8 ;
        reg_count_23_16 <= #TCQ ((reg_count_15_8 == 8'hff) & (reg_count_7_0 == 8'hff)) ? reg_count_23_16 + 1'b1 : reg_count_23_16;

      end 

    end

  end

  assign delayed_sys_reset_n = concat_count[TBIT]; 

endmodule

