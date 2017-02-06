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
// File       : pcie_clocking_v6.v
// Version    : 2.4
//-- Description: Clocking module for Virtex6 PCIe Block
//--
//--
//--
//--------------------------------------------------------------------------------

`timescale 1ns/1ns

module pcie_clocking_v6 # (

  parameter IS_ENDPOINT = "TRUE",
  parameter CAP_LINK_WIDTH = 8,        // 1 - x1 , 2 - x2 , 4 - x4 , 8 - x8
  parameter CAP_LINK_SPEED = 4'h1,     // 1 - Gen1 , 2 - Gen2
  parameter REF_CLK_FREQ = 0,          // 0 - 100 MHz , 1 - 125 MHz , 2 - 250 MHz
  parameter USER_CLK_FREQ = 3          // 0 - 31.25 MHz , 1 - 62.5 MHz , 2 - 125 MHz , 3 - 250 MHz , 4 - 500Mhz

)
(

  input  wire        sys_clk,
  input  wire        gt_pll_lock,
  input  wire        sel_lnk_rate,
  input  wire [1:0]  sel_lnk_width, 

  output wire        sys_clk_bufg,
  output wire        pipe_clk,
  output wire        user_clk,
  output wire        block_clk,
  output wire        drp_clk,
  output wire        clock_locked
   
);

  parameter TCQ = 1;

  wire               mmcm_locked;
  wire               mmcm_clkfbin;
  wire               mmcm_clkfbout;
  wire               mmcm_reset;
  wire               clk_500;
  wire               clk_250;
  wire               clk_125;
  wire               user_clk_prebuf;
  wire               sel_lnk_rate_d; 

  reg  [1:0]         reg_clock_locked = 2'b11;


  // MMCM Configuration

  localparam         mmcm_clockin_period  = (REF_CLK_FREQ == 0) ? 10 : 
                                            (REF_CLK_FREQ == 1) ? 8 : 
                                            (REF_CLK_FREQ == 2) ? 4 : 0;

  localparam         mmcm_clockfb_mult = (REF_CLK_FREQ == 0) ? 10 : 
                                         (REF_CLK_FREQ == 1) ? 8 : 
                                         (REF_CLK_FREQ == 2) ? 8 : 0;

  
  localparam         mmcm_divclk_divide = (REF_CLK_FREQ == 0) ? 1 : 
                                          (REF_CLK_FREQ == 1) ? 1 : 
                                          (REF_CLK_FREQ == 2) ? 2 : 0;

  localparam         mmcm_clock0_div = 4;
  localparam         mmcm_clock1_div = 8;
  localparam         mmcm_clock2_div = ((CAP_LINK_WIDTH == 6'h01) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 0)) ?  32 :
                                       ((CAP_LINK_WIDTH == 6'h01) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 1)) ?  16 :
                                       ((CAP_LINK_WIDTH == 6'h01) && (CAP_LINK_SPEED == 4'h2) && (USER_CLK_FREQ == 1)) ?  16 :
                                       ((CAP_LINK_WIDTH == 6'h02) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 1)) ?  16 : 2;
  localparam         mmcm_clock3_div = 2;

  // MMCM Reset

  assign             mmcm_reset = 1'b0; 

  generate


    // PIPE Clock BUFG.

    if (CAP_LINK_SPEED == 4'h1) begin : GEN1_LINK

      BUFG pipe_clk_bufg (.O(pipe_clk),.I(clk_125));

    end else if (CAP_LINK_SPEED == 4'h2) begin : GEN2_LINK 

      SRL16E #(.INIT(0)) sel_lnk_rate_delay (.Q(sel_lnk_rate_d),
             .D(sel_lnk_rate), .CLK(pipe_clk),.CE(clock_locked), .A3(1'b1),.A2(1'b1),.A1(1'b1),.A0(1'b1));

      BUFGMUX pipe_clk_bufgmux (.O(pipe_clk), .I0(clk_125),.I1(clk_250),.S(sel_lnk_rate_d));

    end else begin : ILLEGAL_LINK_SPEED

      //$display("Confiuration Error : CAP_LINK_SPEED = %d, must be either 1 or 2.", CAP_LINK_SPEED);
      //$finish;

    end

    // User Clock BUFG.

    if ((CAP_LINK_WIDTH == 6'h01) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 0)) begin : x1_GEN1_31_25

      BUFG user_clk_bufg (.O(user_clk),.I(user_clk_prebuf));

    end else if ((CAP_LINK_WIDTH == 6'h01) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 1)) begin : x1_GEN1_62_50

      BUFG user_clk_bufg (.O(user_clk),.I(user_clk_prebuf));

    end else if ((CAP_LINK_WIDTH == 6'h01) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 2)) begin : x1_GEN1_125_00

      BUFG user_clk_bufg (.O(user_clk),.I(clk_125));

    end else if ((CAP_LINK_WIDTH == 6'h01) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 3)) begin : x1_GEN1_250_00
    
      BUFG user_clk_bufg (.O(user_clk),.I(clk_250));

    end else if ((CAP_LINK_WIDTH == 6'h01) && (CAP_LINK_SPEED == 4'h2) && (USER_CLK_FREQ == 1)) begin : x1_GEN2_62_50

      BUFG user_clk_bufg (.O(user_clk),.I(user_clk_prebuf));
    
    end else if ((CAP_LINK_WIDTH == 6'h01) && (CAP_LINK_SPEED == 4'h2) && (USER_CLK_FREQ == 2)) begin : x1_GEN2_125_00
    
      BUFG user_clk_bufg (.O(user_clk),.I(clk_125));

    end else if ((CAP_LINK_WIDTH == 6'h01) && (CAP_LINK_SPEED == 4'h2) && (USER_CLK_FREQ == 3)) begin : x1_GEN2_250_00
    
      BUFG user_clk_bufg (.O(user_clk),.I(clk_250));

    end else if ((CAP_LINK_WIDTH == 6'h02) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 1)) begin : x2_GEN1_62_50

      BUFG user_clk_bufg (.O(user_clk),.I(user_clk_prebuf));
    
    end else if ((CAP_LINK_WIDTH == 6'h02) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 2)) begin : x2_GEN1_125_00
    
      BUFG user_clk_bufg (.O(user_clk),.I(clk_125));

    end else if ((CAP_LINK_WIDTH == 6'h02) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 3)) begin : x2_GEN1_250_00

      BUFG user_clk_bufg (.O(user_clk),.I(clk_250));
    
    end else if ((CAP_LINK_WIDTH == 6'h02) && (CAP_LINK_SPEED == 4'h2) && (USER_CLK_FREQ == 2)) begin : x2_GEN2_125_00

      BUFG user_clk_bufg (.O(user_clk),.I(clk_125));
    
    end else if ((CAP_LINK_WIDTH == 6'h02) && (CAP_LINK_SPEED == 4'h2) && (USER_CLK_FREQ == 3)) begin : x2_GEN2_250_00
    
      BUFG user_clk_bufg (.O(user_clk),.I(clk_250));

    end else if ((CAP_LINK_WIDTH == 6'h04) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 2)) begin : x4_GEN1_125_00
    
      BUFG user_clk_bufg (.O(user_clk),.I(clk_125));

    end else if ((CAP_LINK_WIDTH == 6'h04) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 3)) begin : x4_GEN1_250_00
    
      BUFG user_clk_bufg (.O(user_clk),.I(clk_250));

    end else if ((CAP_LINK_WIDTH == 6'h04) && (CAP_LINK_SPEED == 4'h2) && (USER_CLK_FREQ == 3)) begin : x4_GEN2_250_00
    
      BUFG user_clk_bufg (.O(user_clk),.I(clk_250));

    end else if ((CAP_LINK_WIDTH == 6'h08) && (CAP_LINK_SPEED == 4'h1) && (USER_CLK_FREQ == 3)) begin : x8_GEN1_250_00
    
      BUFG user_clk_bufg (.O(user_clk),.I(clk_250));

    end else if ((CAP_LINK_WIDTH == 6'h08) && (CAP_LINK_SPEED == 4'h2) && (USER_CLK_FREQ == 4)) begin : x8_GEN2_250_00
    
      BUFG user_clk_bufg (.O(user_clk),.I(clk_250));
      BUFG block_clk_bufg (.O(block_clk),.I(clk_500));

    end else begin : ILLEGAL_CONFIGURATION

      //$display("Confiuration Error : Unsupported Link Width, Link Speed and User Clock Frequency Combination");
      //$finish;

    end

  endgenerate

  // DRP clk
  BUFG drp_clk_bufg_i  (.O(drp_clk), .I(clk_125));

  // Feedback BUFG. Required for Temp Compensation
  BUFG clkfbin_bufg_i  (.O(mmcm_clkfbin), .I(mmcm_clkfbout));

  // sys_clk BUFG.
  BUFG sys_clk_bufg_i  (.O(sys_clk_bufg), .I(sys_clk));

  MMCM_ADV # (

    // 5 for 100 MHz , 4 for 125 MHz , 2 for 250 MHz
    .CLKFBOUT_MULT_F (mmcm_clockfb_mult),
    .DIVCLK_DIVIDE (mmcm_divclk_divide),
    .CLKFBOUT_PHASE(0),

    // 10 for 100 MHz, 4 for 250 MHz
    .CLKIN1_PERIOD (mmcm_clockin_period),
    .CLKIN2_PERIOD (mmcm_clockin_period),

    // 500 MHz / mmcm_clockx_div  
    .CLKOUT0_DIVIDE_F (mmcm_clock0_div),
    .CLKOUT0_PHASE (0),

    .CLKOUT1_DIVIDE (mmcm_clock1_div),
    .CLKOUT1_PHASE (0),

    .CLKOUT2_DIVIDE (mmcm_clock2_div),
    .CLKOUT2_PHASE (0),

    .CLKOUT3_DIVIDE (mmcm_clock3_div),
    .CLKOUT3_PHASE (0)

  ) mmcm_adv_i (

    .CLKFBOUT     (mmcm_clkfbout),
    .CLKOUT0      (clk_250),            // 250 MHz for pipe_clk
    .CLKOUT1      (clk_125),            // 125 MHz for pipe_clk
    .CLKOUT2      (user_clk_prebuf),    // user clk
    .CLKOUT3      (clk_500),
    .CLKOUT4      (),
    .CLKOUT5      (),
    .CLKOUT6      (),
    .DO           (),
    .DRDY         (),
    .CLKFBOUTB    (),
    .CLKFBSTOPPED (),
    .CLKINSTOPPED (),
    .CLKOUT0B     (),
    .CLKOUT1B     (),
    .CLKOUT2B     (),
    .CLKOUT3B     (),
    .PSDONE       (),
    .LOCKED       (mmcm_locked),
    .CLKFBIN      (mmcm_clkfbin),
    .CLKIN1       (sys_clk),
    .CLKIN2       (1'b0),
    .CLKINSEL     (1'b1),
    .DADDR        (7'b0),
    .DCLK         (1'b0),
    .DEN          (1'b0),
    .DI           (16'b0),
    .DWE          (1'b0),
    .PSEN         (1'b0),
    .PSINCDEC     (1'b0),
    .PWRDWN       (1'b0),
    .PSCLK        (1'b0),
    .RST          (mmcm_reset)
  );

  // Synchronize MMCM locked output
  always @ (posedge pipe_clk or negedge gt_pll_lock) begin

    if (!gt_pll_lock)
      reg_clock_locked[1:0] <= #TCQ 2'b11;
    else
      reg_clock_locked[1:0] <= #TCQ {reg_clock_locked[0], 1'b0};

  end
  assign  clock_locked = !reg_clock_locked[1] & mmcm_locked;

endmodule

