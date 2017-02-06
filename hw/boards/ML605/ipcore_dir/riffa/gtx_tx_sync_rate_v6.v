
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
// File       : gtx_tx_sync_rate_v6.v
// Version    : 2.4
// Module TX_SYNC

`timescale 1ns / 1ps

module GTX_TX_SYNC_RATE_V6
#(
  parameter    TCQ                = 1,
  parameter    C_SIMULATION       = 0 // Set to 1 for simulation
)
(
  output  reg        ENPMAPHASEALIGN = 1'b0,
  output  reg        PMASETPHASE = 1'b0,
  output  reg        SYNC_DONE = 1'b0,
  output  reg        OUT_DIV_RESET = 1'b0,
  output  reg        PCS_RESET = 1'b0,
  output  reg        USER_PHYSTATUS = 1'b0,
  output  reg        TXALIGNDISABLE = 1'b0,
  output  reg        DELAYALIGNRESET = 1'b0,
  input              USER_CLK,
  input              RESET,
  input              RATE,
  input              RATEDONE,
  input              GT_PHYSTATUS,
  input              RESETDONE

);

  reg                ENPMAPHASEALIGN_c;
  reg                PMASETPHASE_c;
  reg                SYNC_DONE_c;
  reg                OUT_DIV_RESET_c;
  reg                PCS_RESET_c;
  reg                USER_PHYSTATUS_c;
  reg                DELAYALIGNRESET_c;
  reg                TXALIGNDISABLE_c;


  reg [7:0]         waitcounter2;
  reg [7:0]         nextwaitcounter2;
  reg [7:0]         waitcounter;
  reg [7:0]         nextwaitcounter;
  reg [24:0]        state;
  reg [24:0]        nextstate;
  reg               ratedone_r, ratedone_r2;
  wire              ratedone_pulse_i;
  reg               gt_phystatus_q;


  localparam    IDLE                              =  25'b0000000000000000000000001;
  localparam    PHASEALIGN                        =  25'b0000000000000000000000010;
  localparam    RATECHANGE_DIVRESET               =  25'b0000000000000000000000100;
  localparam    RATECHANGE_DIVRESET_POST          =  25'b0000000000000000000001000;
  localparam    RATECHANGE_ENPMADISABLE           =  25'b0000000000000000000010000;
  localparam    RATECHANGE_ENPMADISABLE_POST      =  25'b0000000000000000000100000;
  localparam    RATECHANGE_PMARESET               =  25'b0000000000000000001000000;
  localparam    RATECHANGE_IDLE                   =  25'b0000000000000000010000000;
  localparam    RATECHANGE_PCSRESET               =  25'b0000000000000000100000000;
  localparam    RATECHANGE_PCSRESET_POST          =  25'b0000000000000001000000000;
  localparam    RATECHANGE_ASSERTPHY              =  25'b0000000000000010000000000;
  localparam    RESET_STATE                       =  25'b0000000000000100000000000;
  localparam    WAIT_PHYSTATUS                    =  25'b0000000000010000000000000;
  localparam    RATECHANGE_PMARESET_POST          =  25'b0000000000100000000000000;
  localparam    RATECHANGE_DISABLEPHASE           =  25'b0000000001000000000000000;
  localparam    DELAYALIGNRST                     =  25'b0000000010000000000000000;
  localparam    SETENPMAPHASEALIGN                =  25'b0000000100000000000000000;
  localparam    TXALIGNDISABLEDEASSERT            =  25'b0000001000000000000000000;
  localparam    RATECHANGE_TXDLYALIGNDISABLE      =  25'b0000010000000000000000000;
  localparam    GTXTEST_PULSE_1                   =  25'b0000100000000000000000000;
  localparam    RATECHANGE_DISABLE_TXALIGNDISABLE =  25'b0001000000000000000000000;
  localparam    BEFORE_GTXTEST_PULSE1_1024CLKS    =  25'b0010000000000000000000000;
  localparam    BETWEEN_GTXTEST_PULSES            =  25'b0100000000000000000000000;
  localparam    GTXTEST_PULSE_2                   =  25'b1000000000000000000000000;



  localparam SYNC_IDX = C_SIMULATION ? 0 : 2;
  localparam PMARESET_IDX = C_SIMULATION ? 0: 7;

  always @(posedge USER_CLK) begin

    if(RESET) begin

      state            <= #(TCQ) RESET_STATE;
      waitcounter2     <= #(TCQ) 8'b0;
      waitcounter      <= #(TCQ) 8'b0;
      USER_PHYSTATUS   <= #(TCQ) GT_PHYSTATUS;
      SYNC_DONE        <= #(TCQ) 1'b0;
      ENPMAPHASEALIGN  <= #(TCQ) 1'b1;
      PMASETPHASE      <= #(TCQ) 1'b0;
      OUT_DIV_RESET    <= #(TCQ) 1'b0;
      PCS_RESET        <= #(TCQ) 1'b0;
      DELAYALIGNRESET  <= #(TCQ) 1'b0;
      TXALIGNDISABLE   <= #(TCQ) 1'b1;

    end else begin

      state            <= #(TCQ) nextstate;
      waitcounter2     <= #(TCQ) nextwaitcounter2;
      waitcounter      <= #(TCQ) nextwaitcounter;
      USER_PHYSTATUS   <= #(TCQ) USER_PHYSTATUS_c;
      SYNC_DONE        <= #(TCQ) SYNC_DONE_c;
      ENPMAPHASEALIGN  <= #(TCQ) ENPMAPHASEALIGN_c;
      PMASETPHASE      <= #(TCQ) PMASETPHASE_c;
      OUT_DIV_RESET    <= #(TCQ) OUT_DIV_RESET_c;
      PCS_RESET        <= #(TCQ) PCS_RESET_c;
      DELAYALIGNRESET  <= #(TCQ) DELAYALIGNRESET_c;
      TXALIGNDISABLE   <= #(TCQ) TXALIGNDISABLE_c;

    end

  end

  always @(*) begin

    // DEFAULT CONDITIONS

    DELAYALIGNRESET_c=0;
    SYNC_DONE_c=0;
    ENPMAPHASEALIGN_c=1;
    PMASETPHASE_c=0;
    OUT_DIV_RESET_c=0;
    PCS_RESET_c=0;
    TXALIGNDISABLE_c=0;
    nextstate=state;
    USER_PHYSTATUS_c=GT_PHYSTATUS;
    nextwaitcounter=waitcounter+1'b1;
    nextwaitcounter2= (waitcounter ==8'hff)? waitcounter2 + 1'b1 : waitcounter2 ;

    case(state)

      // START IN RESET
      RESET_STATE : begin

        TXALIGNDISABLE_c=1;
        ENPMAPHASEALIGN_c=0;
        nextstate=BEFORE_GTXTEST_PULSE1_1024CLKS;
        nextwaitcounter=0;
        nextwaitcounter2=0;

      end
      
      // Have to hold for 1024 clocks before asserting GTXTEST[1]
      BEFORE_GTXTEST_PULSE1_1024CLKS : begin

        OUT_DIV_RESET_c=0;
        TXALIGNDISABLE_c=1;
        ENPMAPHASEALIGN_c=0;

        if(waitcounter2[1]) begin

          nextstate=GTXTEST_PULSE_1;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // Assert GTXTEST[1] for 256 clocks.  Figure 3-9 UG366
      GTXTEST_PULSE_1: begin

        OUT_DIV_RESET_c=1;
        TXALIGNDISABLE_c=1;
        ENPMAPHASEALIGN_c=0;

        if(waitcounter[7]) begin

          nextstate=BETWEEN_GTXTEST_PULSES;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // De-assert GTXTEST[1] for 256 clocks. Figure 3-9 UG366
      BETWEEN_GTXTEST_PULSES: begin

        OUT_DIV_RESET_c=0;
        TXALIGNDISABLE_c=1;
        ENPMAPHASEALIGN_c=0;

        if(waitcounter[7]) begin

          nextstate=GTXTEST_PULSE_2;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // Assert GTXTEST[1] for 256 clocks a second time.  Figure 3-9 UG366 
      GTXTEST_PULSE_2: begin

        OUT_DIV_RESET_c=1;
        TXALIGNDISABLE_c=1;
        ENPMAPHASEALIGN_c=0;

        if(waitcounter[7]) begin

          nextstate=DELAYALIGNRST;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end



      // ASSERT TXDLYALIGNRESET FOR 16 CLOCK CYCLES
      DELAYALIGNRST : begin

        DELAYALIGNRESET_c=1;
        ENPMAPHASEALIGN_c=0;
        TXALIGNDISABLE_c=1;

        if(waitcounter[4]) begin

          nextstate=SETENPMAPHASEALIGN;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // ASSERT ENPMAPHASEALIGN FOR 32 CLOCK CYCLES
      SETENPMAPHASEALIGN : begin

        TXALIGNDISABLE_c=1;

        if(waitcounter[5]) begin

          nextstate=PHASEALIGN;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // ASSERT PMASETPHASE OUT OF RESET for 32K CYCLES
      PHASEALIGN : begin

        PMASETPHASE_c=1;
        TXALIGNDISABLE_c=1;

          if(waitcounter2[PMARESET_IDX]) begin

            nextstate=TXALIGNDISABLEDEASSERT;
            nextwaitcounter=0;
            nextwaitcounter2=0;

          end

      end

      // KEEP TXALIGNDISABLE ASSERTED for 64 CYCLES
      TXALIGNDISABLEDEASSERT : begin

        TXALIGNDISABLE_c=1;

        if(waitcounter[6]) begin

            nextwaitcounter=0;
            nextstate=IDLE;
            nextwaitcounter2=0;

        end

      end

      // NOW IN IDLE, ASSERT SYNC DONE, WAIT FOR RATECHANGE
      IDLE : begin

        SYNC_DONE_c=1;

        if(ratedone_pulse_i) begin

          USER_PHYSTATUS_c=0;
          nextstate=WAIT_PHYSTATUS;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // WAIT FOR PHYSTATUS
      WAIT_PHYSTATUS : begin

        USER_PHYSTATUS_c=0;

        if(gt_phystatus_q) begin

          nextstate=RATECHANGE_IDLE;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // WAIT 64 CYCLES BEFORE WE START THE RATE CHANGE
      RATECHANGE_IDLE : begin

        USER_PHYSTATUS_c=0;

        if(waitcounter[6]) begin

          nextstate=RATECHANGE_TXDLYALIGNDISABLE;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // ASSERT TXALIGNDISABLE FOR 32 CYCLES
      RATECHANGE_TXDLYALIGNDISABLE : begin

        USER_PHYSTATUS_c=0;
        TXALIGNDISABLE_c=1;

        if(waitcounter[5]) begin

          nextstate=RATECHANGE_DIVRESET;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // ASSERT DIV RESET FOR 16 CLOCK CYCLES
      RATECHANGE_DIVRESET : begin

        OUT_DIV_RESET_c=1;
        USER_PHYSTATUS_c=0;
        TXALIGNDISABLE_c=1;

        if(waitcounter[4]) begin

          nextstate=RATECHANGE_DIVRESET_POST;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // WAIT FOR 32 CLOCK CYCLES BEFORE NEXT STEP
      RATECHANGE_DIVRESET_POST : begin

        USER_PHYSTATUS_c=0;
        TXALIGNDISABLE_c=1;

        if(waitcounter[5]) begin

          nextstate=RATECHANGE_PMARESET;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // ASSERT PMA RESET FOR 32K CYCLES
      RATECHANGE_PMARESET : begin

        PMASETPHASE_c=1;
        USER_PHYSTATUS_c=0;
        TXALIGNDISABLE_c=1;

        if(waitcounter2[PMARESET_IDX]) begin

            nextstate=RATECHANGE_PMARESET_POST;
            nextwaitcounter=0;
            nextwaitcounter2=0;

        end

      end


      // WAIT FOR 32 CYCLES BEFORE DISABLING TXALIGNDISABLE
      RATECHANGE_PMARESET_POST : begin

        USER_PHYSTATUS_c=0;
        TXALIGNDISABLE_c=1;

        if(waitcounter[5]) begin

          nextstate=RATECHANGE_DISABLE_TXALIGNDISABLE;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // DISABLE TXALIGNDISABLE FOR 32 CYCLES
      RATECHANGE_DISABLE_TXALIGNDISABLE : begin

        USER_PHYSTATUS_c=0;

        if(waitcounter[5]) begin

          nextstate=RATECHANGE_PCSRESET;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end
      end

      // NOW ASSERT PCS RESET FOR 32 CYCLES
      RATECHANGE_PCSRESET : begin

        PCS_RESET_c=1;

        USER_PHYSTATUS_c=0;

        if(waitcounter[5]) begin

          nextstate=RATECHANGE_PCSRESET_POST;
          nextwaitcounter=0;
          nextwaitcounter2=0;

        end

      end

      // WAIT FOR RESETDONE BEFORE ASSERTING PHY_STATUS_OUT
      RATECHANGE_PCSRESET_POST : begin

        USER_PHYSTATUS_c=0;

        if(RESETDONE) begin

          nextstate=RATECHANGE_ASSERTPHY;

        end

      end

      // ASSERT PHYSTATUSOUT MEANING RATECHANGE IS DONE AND GO BACK TO IDLE
      RATECHANGE_ASSERTPHY : begin

        USER_PHYSTATUS_c=1;
        nextstate=IDLE;

      end

    endcase

  end

  // Generate Ratechange Pulse

  always @(posedge USER_CLK) begin

    if (RESET) begin

      ratedone_r  <= #(TCQ) 1'b0;
      ratedone_r2 <= #(TCQ) 1'b0;
      gt_phystatus_q <= #(TCQ) 1'b0;


    end else begin

      ratedone_r  <= #(TCQ) RATE;
      ratedone_r2 <= #(TCQ) ratedone_r;
      gt_phystatus_q <= #(TCQ) GT_PHYSTATUS;

    end

  end

  assign ratedone_pulse_i = (ratedone_r != ratedone_r2);

endmodule



