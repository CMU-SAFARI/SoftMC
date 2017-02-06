`timescale 1ns/1ns
//----------------------------------------------------------------------------
// This software is Copyright © 2012 The Regents of the University of 
// California. All Rights Reserved.
//
// Permission to copy, modify, and distribute this software and its 
// documentation for educational, research and non-profit purposes, without 
// fee, and without a written agreement is hereby granted, provided that the 
// above copyright notice, this paragraph and the following three paragraphs 
// appear in all copies.
//
// Permission to make commercial use of this software may be obtained by 
// contacting:
// Technology Transfer Office
// 9500 Gilman Drive, Mail Code 0910
// University of California
// La Jolla, CA 92093-0910
// (858) 534-5815
// invent@ucsd.edu
// 
// This software program and documentation are copyrighted by The Regents of 
// the University of California. The software program and documentation are 
// supplied "as is", without any accompanying services from The Regents. The 
// Regents does not warrant that the operation of the program will be 
// uninterrupted or error-free. The end-user understands that the program was 
// developed for research purposes and is advised not to rely exclusively on 
// the program for any reason.
// 
// IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO
// ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR
// CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING
// OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
// EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF
// THE POSSIBILITY OF SUCH DAMAGE. THE UNIVERSITY OF
// CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
// THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, 
// AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATIONS TO
// PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
// MODIFICATIONS.
//----------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:27:32 05/15/2014 
// Design Name: 
// Module Name:    tx_qword_aligner_128
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description:
// Shifts the data payload of outgoing TLP's to conform to Altera's Quad-word
// alignment requirement. This module has a 2 cycle latency. It also handles the
// 2 cycle Transmit ready latency from the specification.
//
// Dependencies: None
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`define S_TXALIGNER128UP_IDLE 2'b00
`define S_TXALIGNER128UP_HDR0 2'b01
`define S_TXALIGNER128UP_PAY  2'b10

`define S_TXALIGNER128LOW_IDLE    2'b00
`define S_TXALIGNER128LOW_PROC    2'b01
`define S_TXALIGNER128LOW_PREOVFL 2'b10
`define S_TXALIGNER128LOW_OVFL    2'b11

module tx_qword_aligner_128
  #(
    parameter C_ALTERA = 1'b1,
    parameter C_PCI_DATA_WIDTH = 9'd128,
    parameter C_TX_READY_LATENCY = 3'd2
    )
   (
    input                         CLK,
    input                         RST_IN,

    input [C_PCI_DATA_WIDTH-1:0]  TX_DATA,
    input                         TX_DATA_VALID,
    output                        TX_DATA_READY,
    input                         TX_TLP_END_FLAG,
    input                         TX_TLP_START_FLAG,

    output [C_PCI_DATA_WIDTH-1:0] TX_ST_DATA, 
    output [0:0]                  TX_ST_VALID,
    input                         TX_ST_READY,
    output [0:0]                  TX_ST_EOP,
    output [0:0]                  TX_ST_SOP,
    output                        TX_ST_EMPTY
    );

   reg [C_TX_READY_LATENCY-1:0]   rTxStReady=0, _rTxStReady=0;

   // Registers for first cycle of pipeline (upper)
   // Capture
   reg [C_PCI_DATA_WIDTH-1:0]     rTxData=0,_rTxData=0;
   reg                            rTxDataValid=0, _rTxDataValid=0;
   reg                            rTxTlpEndFlag=0, _rTxTlpEndFlag=0;
   reg                            rTxTlpStartFlag=0, _rTxTlpStartFlag=0;
   // Computed
   reg [1:0]                      rOverflow=0, _rOverflow=0;
   reg [9:0]                      rRealLength=0, _rRealLength=0;
   reg [9:0]                      rAdjLength=0, _rAdjLength=0;
   reg                            rInsBlank=0,_rInsBlank=0;                              

   // State (controls pipeline)
   reg [1:0]                      rUpState=0, _rUpState=0;

   // Second cycle of pipeline (lower)
   reg [C_PCI_DATA_WIDTH+32-1:0]  rAlignBuffer=0, _rAlignBuffer=0;
   reg [1:0]                      rLowState=0, _rLowState=0;
   reg                            rSel=0, _rSel=0;
   reg                            rTrigger=0,_rTrigger=0;

   // Registered outputs
   reg                            rTxStValid=0,_rTxStValid=0;
   reg                            rTxStEop=0,_rTxStEop=0;
   reg                            rTxStSop=0,_rTxStSop=0;
   reg                            rTxStEmpty=0,_rTxStEmpty=0;

   wire [1:0]                     wRegEn;   

   // Wires (unregistered) from input
   wire [2:0]                     wFMT;
   wire [63:0]                    w4DWHAddr;
   wire [31:0]                    w3DWHAddr;
   wire                           w3DWH;
   wire                           w4DWH;
   wire                           wInsBlank;
   wire                           w4DWHQWA;
   wire                           w3DWHQWA;
   wire [9:0]                     wLength;
   wire                           wDataTLP;
   wire                           w3DWHInsBlank;
   wire                           w4DWHInsBlank;
   // Overflow indicating wire to the second stage of the pipeline
   wire                           wOverflow;

   wire                           wSMLowEnable;
   wire                           wSMUpEnable; 
   wire                           wTxStEopCondition;

   wire [255:0]                   wAlignBufMux;     

   // Wires from the unregistered TLP Header
   assign wFMT = TX_DATA[31:29];
   assign w4DWHAddr = {TX_DATA[95:64],TX_DATA[127:96]};
   assign w3DWHAddr = TX_DATA[95:64];
   assign wLength = TX_DATA[9:0];
   assign w4DWH = wFMT[0];
   assign w3DWH = ~wFMT[0];
   assign wDataTLP = wFMT[1];
   assign w4DWHQWA = ~w4DWHAddr[2];
   assign w3DWHQWA = ~w3DWHAddr[2];
   assign w3DWHInsBlank = w3DWHQWA & w3DWH & wDataTLP;
   assign w4DWHInsBlank = ~w4DWHQWA & w4DWH & wDataTLP;
   assign wInsBlank = w3DWHInsBlank | w4DWHInsBlank; // Insert a blank DW after the header

   assign wRegEn[0] = (~rTxDataValid | wRegEn[1]);
   assign wSMUpEnable = wRegEn[0];
   assign TX_DATA_READY = wRegEn[0];

   // Unconditional input capture
   always @(*) begin 
      _rTxStReady = (rTxStReady << 1) | TX_ST_READY;
   end

   always @(posedge CLK) begin
      rTxStReady <= _rTxStReady;
   end

   // All of these signals are "valid" when rTxTlpStartFlag and rTxDataValid is high
   always @(*) begin 
      _rInsBlank = wInsBlank & TX_TLP_START_FLAG & TX_DATA_VALID;
      _rRealLength = wLength + {7'd0,{w4DWH,~w4DWH,~w4DWH}};
      _rAdjLength = wLength + {9'd0,wInsBlank} + {7'd0,{w4DWH,~w4DWH,~w4DWH}};

      _rTxData = TX_DATA;
      _rTxTlpEndFlag = TX_TLP_END_FLAG & TX_DATA_VALID;
      _rTxTlpStartFlag = TX_TLP_START_FLAG & TX_DATA_VALID;
   end // always @ begin

   always @(posedge CLK) begin
      rInsBlank <= _rInsBlank;
      rRealLength <= _rRealLength;
      rAdjLength <= _rAdjLength;
      
      if(wRegEn[0]) begin
         rTxData <= _rTxData;
         rTxTlpEndFlag <= _rTxTlpEndFlag;
         rTxTlpStartFlag <= _rTxTlpStartFlag;
      end
   end
   
   always @(*) begin
      _rOverflow[0] = TX_TLP_START_FLAG & TX_TLP_END_FLAG & w3DWHInsBlank;
      _rOverflow[1] = rTxTlpStartFlag & (rRealLength[9:2] < rAdjLength[9:2]); 
   end // always @ begin

   always @(posedge CLK) begin
      if(wSMUpEnable) begin
	 rOverflow[0] <= _rOverflow[0];
	 rOverflow[1] <= _rOverflow[1];
      end
   end

   // State machine for the upper pipeline
   // Valid never goes down inside of a TLP.
   always @(*) begin
      _rTxDataValid = rTxDataValid;

      if(wSMUpEnable & TX_DATA_VALID) begin
         _rTxDataValid = 1'b1;
      end else if ( wSMUpEnable & rTxTlpEndFlag)begin
         _rTxDataValid = 1'b0;
      end

      _rUpState = rUpState;
      case (rUpState)
        `S_TXALIGNER128UP_IDLE: begin
           if (TX_DATA_VALID & wRegEn[0]) begin
              _rUpState = `S_TXALIGNER128UP_HDR0;
           end
        end
        `S_TXALIGNER128UP_HDR0: begin
           if(wSMUpEnable) begin
              casex ({rTxTlpEndFlag,TX_DATA_VALID})
                2'b0x: _rUpState = `S_TXALIGNER128UP_PAY;
                2'b10: _rUpState = `S_TXALIGNER128UP_IDLE;
                2'b11: _rUpState = `S_TXALIGNER128UP_HDR0;
              endcase // case (rTxTlpEndFlag)
           end
        end
        `S_TXALIGNER128UP_PAY : begin
           if(wSMUpEnable) begin
              casex ({rTxTlpEndFlag,TX_DATA_VALID})
                2'b0x: _rUpState = `S_TXALIGNER128UP_PAY;
                2'b10: _rUpState = `S_TXALIGNER128UP_IDLE;
                2'b11: _rUpState = `S_TXALIGNER128UP_HDR0;
              endcase // case (rTxTlpEndFlag)
           end
        end
        default: _rUpState = `S_TXALIGNER128UP_IDLE;
      endcase // case (rUpState)
   end // always @ begin

   always @(posedge CLK) begin
      if(RST_IN) begin
         rTxDataValid <= 0;
         rUpState <= `S_TXALIGNER128UP_IDLE;
      end else begin
         rTxDataValid <= _rTxDataValid;
         rUpState <= _rUpState;
      end
   end // always @ (posedge CLK)

   // These signals comprise the lower aligner
   assign wSMLowEnable = rTxStReady[C_TX_READY_LATENCY-1] | ~rTxStValid;
   assign wRegEn[1] = ~(rLowState == `S_TXALIGNER128LOW_PREOVFL & rTrigger) & (wSMLowEnable); 

   assign wOverflow = (rOverflow[0] | rOverflow[1]);
   assign wAlignBufMux = ({{rTxData[95:0],rAlignBuffer[159:128]},rTxData}) >> ({rSel,7'd0});

   always @(*) begin
      _rAlignBuffer = {rTxData[127:96], wAlignBufMux[127:0]};
   end // always @ begin

   always @(posedge CLK) begin
      if(wSMLowEnable) begin
         rAlignBuffer <= _rAlignBuffer; 
      end
   end

   assign wTxStEopCondition = (rLowState == `S_TXALIGNER128LOW_PREOVFL & rTrigger) | 
                              (rLowState != `S_TXALIGNER128LOW_PREOVFL & {rTxTlpEndFlag,wOverflow,rTxDataValid} == 3'b101);

   // Valid never goes down inside of a TLP.
   always @(*) begin
      _rLowState = rLowState;
      _rTrigger = rTrigger;
      _rTxStValid = rTxStValid;
      _rTxStEop = rTxStEop;
      _rTxStSop = rTxStSop;
      _rSel = rSel;

      _rTxStEop = wTxStEopCondition;
      _rTrigger = rTxTlpEndFlag & rTxDataValid;
      _rTxStEmpty = (rAdjLength[1:0] == 2'b01) | (rAdjLength[1:0] == 2'b10);

      // Take the next txDataValid if we are taking data
      // and it's a start flag and the data is valid
      if ( wRegEn[1] & rTxTlpStartFlag & rTxDataValid ) begin
         _rTxStValid = 1;
      end else if ( wSMLowEnable & rTxStEop ) begin
         _rTxStValid = 0;
      end

      if ( wRegEn[1] & rTxDataValid ) begin // DOUBLE CHECK
         _rTxStSop = rTxTlpStartFlag;
      end else if ( wSMLowEnable ) begin
         _rTxStSop = 0;
      end

      // rSel should be set on wInsBlank kept high until the end of the packet
      // Note: rSel is only applicable in multi-cycle packets
      if (wSMLowEnable & rInsBlank) begin
         _rSel = 1'b1;
      end else if (wSMLowEnable & wTxStEopCondition) begin
         _rSel = 1'b0;
      end
      
      case (rLowState)
        `S_TXALIGNER128LOW_IDLE : begin
           if(wSMLowEnable) begin
              casex({rTxTlpEndFlag,wOverflow,rTxDataValid})      // Set the state for the next cycle
                3'bxx0: _rLowState = `S_TXALIGNER128LOW_IDLE;    // Stay here
                3'b001: _rLowState = `S_TXALIGNER128LOW_PROC;    // Process
                3'b011: _rLowState = `S_TXALIGNER128LOW_PREOVFL; // Don't set rTxStEop (set trigger)
                3'b101: _rLowState = `S_TXALIGNER128LOW_PROC;    // Set rTxStEop
                3'b111: _rLowState = `S_TXALIGNER128LOW_PREOVFL; // Don't set rTxStEop (set trigger)
              endcase
           end
        end
        `S_TXALIGNER128LOW_PROC : begin
           if(wSMLowEnable) begin
              casex({rTxTlpEndFlag,wOverflow,rTxDataValid})     // Set the state for the next cycle
                3'bxx0: _rLowState = `S_TXALIGNER128LOW_IDLE;    // If the next cycle is not valid Eop must have been set this cycle and we should go to idle
                3'b001: _rLowState = `S_TXALIGNER128LOW_PROC;    // Continue processing
                3'b011: _rLowState = `S_TXALIGNER128LOW_PREOVFL; // Don't set rTxStEop (set trigger)
                3'b101: _rLowState = `S_TXALIGNER128LOW_PROC;    // set rTxStEop 
                3'b111: _rLowState = `S_TXALIGNER128LOW_PREOVFL; // Don't set rTxStEop (set trigger)
              endcase
           end
        end
        `S_TXALIGNER128LOW_PREOVFL : begin
           if(wSMLowEnable) begin
              if(rTrigger) begin
                 _rLowState = `S_TXALIGNER128LOW_OVFL;
              end
           end
        end
        `S_TXALIGNER128LOW_OVFL : begin
           if(wSMLowEnable) begin
              casex({rTxTlpEndFlag,wOverflow,rTxDataValid})     // Set the state for the next cycle
                3'bxx0: _rLowState = `S_TXALIGNER128LOW_IDLE;    // If the next cycle is not valid Eop must have been set this cycle and we should go to idle
                3'b001: _rLowState = `S_TXALIGNER128LOW_PROC;    // Continue processing
                3'b011: _rLowState = `S_TXALIGNER128LOW_PREOVFL; // Don't set rTxStEop (Don't set trigger)
                3'b101: _rLowState = `S_TXALIGNER128LOW_PROC;    // set rTxStEop
                3'b111: _rLowState = `S_TXALIGNER128LOW_PREOVFL; // Don't set rTxStEop (set trigger)
              endcase
           end
        end
      endcase
   end // always @ begin
   
   always @(posedge CLK) begin
      if(RST_IN) begin
         rLowState <= `S_TXALIGNER128LOW_IDLE;
         rTxStValid <= 0;
         rTxStSop <= 0;
         rSel <= 0;
      end else begin
         rTxStValid <= _rTxStValid;
         rTxStSop <= _rTxStSop;
         rSel <= _rSel;
         rLowState <= _rLowState;
      end // else: !if(RST_IN)
      if (RST_IN) begin
         rTxStEop <= 1'b0;
      end else if (wSMLowEnable) begin
         rTxStEop <= _rTxStEop;
      end
      if (RST_IN) begin
         rTrigger <= 1'b0;
      end else if (wRegEn[1]) begin
         rTrigger <= _rTrigger;
      end
      if (RST_IN) begin
         rTxStEmpty <= 1'b0;
      end else if(wRegEn[1] & rTxTlpStartFlag) begin
         rTxStEmpty <= _rTxStEmpty;
      end
   end // always @ (posedge CLK)

   // Outputs from the aligner to the PCIe Core
   assign TX_ST_VALID = (rTxStValid & rTxStReady[C_TX_READY_LATENCY-1]);
   assign TX_ST_EOP = rTxStEop;
   assign TX_ST_SOP = rTxStSop;
   assign TX_ST_EMPTY = rTxStEmpty;
   assign TX_ST_DATA = rAlignBuffer[127:0];
endmodule
