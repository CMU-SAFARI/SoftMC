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
// File       : pcie_upconfig_fix_3451_v6.v
// Version    : 2.4
//--
//-- Description: Virtex6 Workaround for Root Port Upconfigurability Bug
//--
//--
//--------------------------------------------------------------------------------

`timescale 1ns/1ns

module pcie_upconfig_fix_3451_v6 # (

  parameter                                     UPSTREAM_FACING = "TRUE",
  parameter                                     PL_FAST_TRAIN = "FALSE",
  parameter                                     LINK_CAP_MAX_LINK_WIDTH = 6'h08,
  parameter                                     TCQ = 1

)
(

  input                                         pipe_clk,
  input                                         pl_phy_lnkup_n,

  input  [5:0]                                  pl_ltssm_state,
  input                                         pl_sel_lnk_rate,
  input  [1:0]                                  pl_directed_link_change,

  input  [3:0]                                  cfg_link_status_negotiated_width,
  input  [15:0]                                 pipe_rx0_data,
  input  [1:0]                                  pipe_rx0_char_isk,

  output                                        filter_pipe

);


  reg                                           reg_filter_pipe;
  reg  [15:0]                                   reg_tsx_counter;
  wire [15:0]                                   tsx_counter;

  wire [5:0]                                    cap_link_width;

  // Corrupting all Tsx on all lanes as soon as we do R.RC->R.RI transition to allow time for
  // the core to see the TS1s on all the lanes being configured at the same time
  // R.RI has a 2ms timeout.Corrupting tsxs for ~1/4 of that time
  // 225 pipe_clk cycles-sim_fast_train
  // 60000 pipe_clk cycles-without sim_fast_train
  // Not taking any action  when PLDIRECTEDLINKCHANGE is set

// Detect xx, COM then PAD,xx or COM,PAD then PAD,xx
// data0 will be the first symbol on lane 0, data1 will be the next symbol.
//  Don't look for PAD on data1 since it's unnecessary.
// COM=0xbc and PAD=0xf7 (and isk).
// detect if (data & 0xb4) == 0xb4 and isk, and then
//  if (data & 0x4b) == 0x08 or 0x43.  This distinguishes COM and PAD, using
//  no more than a 6-input LUT, so should be "free".

reg reg_filter_used, reg_com_then_pad;
reg reg_data0_b4, reg_data0_08, reg_data0_43;
reg reg_data1_b4, reg_data1_08, reg_data1_43;
reg reg_data0_com, reg_data1_com, reg_data1_pad;

wire  data0_b4 = pipe_rx0_char_isk[0] &&
        ((pipe_rx0_data[7:0] & 8'hb4) == 8'hb4);
wire  data0_08 = ((pipe_rx0_data[7:0] & 8'h4b) == 8'h08);
wire  data0_43 = ((pipe_rx0_data[7:0] & 8'h4b) == 8'h43);
wire  data1_b4 = pipe_rx0_char_isk[1] &&
        ((pipe_rx0_data[15:8] & 8'hb4) == 8'hb4);
wire  data1_08 = ((pipe_rx0_data[15:8] & 8'h4b) == 8'h08);
wire  data1_43 = ((pipe_rx0_data[15:8] & 8'h4b) == 8'h43);

wire  data0_com = reg_data0_b4 && reg_data0_08;
wire  data1_com = reg_data1_b4 && reg_data1_08;
wire  data0_pad = reg_data0_b4 && reg_data0_43;
wire  data1_pad = reg_data1_b4 && reg_data1_43;

wire  com_then_pad0 = reg_data0_com && reg_data1_pad && data0_pad;
wire  com_then_pad1 = reg_data1_com && data0_pad && data1_pad;
wire  com_then_pad = (com_then_pad0 || com_then_pad1) && ~reg_filter_used;
wire  filter_used = (pl_ltssm_state == 6'h20) &&
        (reg_filter_pipe || reg_filter_used);

  always @(posedge pipe_clk) begin

    reg_data0_b4 <= #TCQ data0_b4;
    reg_data0_08 <= #TCQ data0_08;
    reg_data0_43 <= #TCQ data0_43;
    reg_data1_b4 <= #TCQ data1_b4;
    reg_data1_08 <= #TCQ data1_08;
    reg_data1_43 <= #TCQ data1_43;
    reg_data0_com <= #TCQ data0_com;
    reg_data1_com <= #TCQ data1_com;
    reg_data1_pad <= #TCQ data1_pad;
    reg_com_then_pad <= #TCQ (~pl_phy_lnkup_n) ? com_then_pad : 1'b0;
    reg_filter_used <= #TCQ (~pl_phy_lnkup_n) ? filter_used : 1'b0;

  end

  always @ (posedge pipe_clk) begin

    if (pl_phy_lnkup_n) begin

      reg_tsx_counter <= #TCQ 16'h0;
      reg_filter_pipe <= #TCQ 1'b0;

    end else if ((pl_ltssm_state == 6'h20) &&
     reg_com_then_pad &&
                 (cfg_link_status_negotiated_width != cap_link_width) &&
                 (pl_directed_link_change[1:0] == 2'b00)) begin

      reg_tsx_counter <= #TCQ 16'h0;
      reg_filter_pipe <= #TCQ 1'b1;

    end else if (filter_pipe == 1'b1) begin

      if (tsx_counter < ((PL_FAST_TRAIN == "TRUE") ? 16'd225: pl_sel_lnk_rate ? 16'd800 : 16'd400)) begin

        reg_tsx_counter <= #TCQ tsx_counter + 1'b1;
        reg_filter_pipe <= #TCQ 1'b1;

      end else begin

        reg_tsx_counter <= #TCQ 16'h0;
        reg_filter_pipe <= #TCQ 1'b0;

      end

    end

  end

  assign filter_pipe = (UPSTREAM_FACING == "TRUE") ? 1'b0 : reg_filter_pipe;
  assign tsx_counter = reg_tsx_counter;

  assign cap_link_width = LINK_CAP_MAX_LINK_WIDTH;

endmodule
