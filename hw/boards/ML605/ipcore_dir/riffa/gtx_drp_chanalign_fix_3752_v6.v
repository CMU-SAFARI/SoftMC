
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
// File       : gtx_drp_chanalign_fix_3752_v6.v
// Version    : 2.4
//--
//-- Description: Virtex6 Workaround for deadlock due lane-lane skew Bug
//--
//--
//--
//--------------------------------------------------------------------------------

`timescale 1ns / 1ps
module GTX_DRP_CHANALIGN_FIX_3752_V6
#(
  parameter       TCQ             = 1,
  parameter       C_SIMULATION    = 0 // Set to 1 for simulation
)
(
  output  reg          dwe,
  output  reg  [15:0]  din,    //THIS IS THE INPUT TO THE DRP
  output  reg          den,
  output  reg  [7:0]   daddr,
  output  reg  [3:0]   drpstate,
  input                write_ts1,
  input                write_fts,
  input       [15:0]   dout,  //THIS IS THE OUTPUT OF THE DRP
  input                drdy,
  input                Reset_n,
  input                drp_clk

);


  reg  [7:0]     next_daddr;
  reg  [3:0]     next_drpstate;



  reg            write_ts1_gated;
  reg            write_fts_gated;


  localparam      DRP_IDLE_FTS           =  1;
  localparam      DRP_IDLE_TS1           =  2;
  localparam      DRP_RESET              =  3;
  localparam      DRP_WRITE_FTS          =  6;
  localparam      DRP_WRITE_DONE_FTS     =  7;
  localparam      DRP_WRITE_TS1          =  8;
  localparam      DRP_WRITE_DONE_TS1     =  9;
  localparam      DRP_COM                = 10'b0110111100;
  localparam      DRP_FTS                = 10'b0100111100;
  localparam      DRP_TS1                = 10'b0001001010;


  always @(posedge drp_clk) begin

    if ( ~Reset_n ) begin

      daddr     <= #(TCQ) 8'h8;
      drpstate  <= #(TCQ) DRP_RESET;


      write_ts1_gated <= #(TCQ) 0;
      write_fts_gated <= #(TCQ) 0;

    end else begin

      daddr     <= #(TCQ) next_daddr;
      drpstate  <= #(TCQ) next_drpstate;



      write_ts1_gated <= #(TCQ) write_ts1;
      write_fts_gated <= #(TCQ) write_fts;

    end

  end


  always @(*) begin

    // DEFAULT CONDITIONS
    next_drpstate=drpstate;
    next_daddr=daddr;
    den=0;
    din=0;
    dwe=0;

    case(drpstate)

      // RESET CONDITION, WE NEED TO READ THE TOP 6 BITS OF THE DRP REGISTER WHEN WE GET THE WRITE FTS TRIGGER
      DRP_RESET : begin

        next_drpstate= DRP_WRITE_TS1;
        next_daddr=8'h8;

      end



      // WRITE FTS SEQUENCE
      DRP_WRITE_FTS : begin

        den=1;
        dwe=1;
        case (daddr)
          8'h8 : din = 16'hFD3C;
          8'h9 : din = 16'hC53C;
          8'hA : din = 16'hFDBC;
          8'hB : din = 16'h853C;
        endcase
        next_drpstate=DRP_WRITE_DONE_FTS;

      end

      // WAIT FOR FTS SEQUENCE WRITE TO FINISH, ONCE WE FINISH ALL WRITES GO TO FTS IDLE
      DRP_WRITE_DONE_FTS : begin

        if(drdy) begin

          if(daddr==8'hB) begin

            next_drpstate=DRP_IDLE_FTS;
            next_daddr=8'h8;

          end else begin

            next_drpstate=DRP_WRITE_FTS;
            next_daddr=daddr+1'b1;

          end

        end

      end

      // FTS IDLE: WAIT HERE UNTIL WE NEED TO WRITE TS1
      DRP_IDLE_FTS : begin

        if(write_ts1_gated) begin

          next_drpstate=DRP_WRITE_TS1;
          next_daddr=8'h8;

        end

      end

      // WRITE TS1 SEQUENCE
      DRP_WRITE_TS1 : begin
        den=1;
        dwe=1;
        case (daddr)
          8'h8 : din = 16'hFC4A;
          8'h9 : din = 16'hDC4A;
          8'hA : din = 16'hC04A;
          8'hB : din = 16'h85BC;
        endcase
        next_drpstate=DRP_WRITE_DONE_TS1;

      end

      // WAIT FOR TS1 SEQUENCE WRITE TO FINISH, ONCE WE FINISH ALL WRITES GO TO TS1 IDLE
      DRP_WRITE_DONE_TS1 : begin

        if(drdy) begin

          if(daddr==8'hB) begin

            next_drpstate=DRP_IDLE_TS1;
            next_daddr=8'h8;

          end else begin

            next_drpstate=DRP_WRITE_TS1;
            next_daddr=daddr+1'b1;

          end

        end

      end

      // TS1 IDLE: WAIT HERE UNTIL WE NEED TO WRITE FTS
      DRP_IDLE_TS1 : begin

        if(write_fts_gated) begin

          next_drpstate=DRP_WRITE_FTS;
          next_daddr=8'h8;

        end

      end

    endcase

  end

endmodule
