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
// Create Date:    19:27:32 06/14/2012 
// Design Name: 
// Module Name:    tx_qword_aligner_64 
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
`define S_TXALIGNER64UP_IDLE 2'b00
`define S_TXALIGNER64UP_HDR0 2'b01
`define S_TXALIGNER64UP_HDR1 2'b10
`define S_TXALIGNER64UP_PAY  2'b11

`define S_TXALIGNER64LOW_IDLE 2'b00
`define S_TXALIGNER64LOW_PROC 2'b01
`define S_TXALIGNER64LOW_PREOVFL 2'b10
`define S_TXALIGNER64LOW_OVFL 2'b11

module tx_qword_aligner_64
  #(
    parameter C_ALTERA = 1'b1,
    parameter C_PCI_DATA_WIDTH = 9'd64,
    parameter C_TX_READY_LATENCY = 3'd1
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

   reg [C_TX_READY_LATENCY-1:0]   rTxStReady, _rTxStReady;

   // Registers for first cycle of pipeline (upper)
   // Capture
   reg [C_PCI_DATA_WIDTH-1:0]     rTxData,_rTxData;
   reg                            rTxDataValid, _rTxDataValid;
   reg                            rTxTlpEndFlag, _rTxTlpEndFlag;
   reg                            rTxTlpStartFlag, _rTxTlpStartFlag;

   // Registers for the second cycle of the state machine
   reg                            r3DWHInsBlank,_r3DWHInsBlank;
   reg [C_PCI_DATA_WIDTH+32-1:0]  rAlignBuffer, _rAlignBuffer;

   // Registers for the third cycle of the state machine
   reg                            r4DWHInsBlank,_r4DWHInsBlank;

   // State (controls upper pipeline)
   reg [1:0]                      rUpState, _rUpState;
   reg                            rSel, _rSel;
   reg                            rTrigger,_rTrigger;
   
   // Second stage of pipeline (lower)
   reg [1:0]                      rLowState, _rLowState;

   // Registered Outputs
   reg                            rTxStValid,_rTxStValid;
   reg                            rTxStEop,_rTxStEop;
   reg                            rTxStSop,_rTxStSop;
   
   // Wires
   wire [1:0]                     wRegEn;

   reg                            r4DWH, _r4DWH;
   reg                            r3DWH, _r3DWH;
   reg                            rDataTLP, _rDataTLP;
   reg                            rLenEven,_rLenEven;
   reg                            rLenOdd,_rLenOdd;
   reg                            r4DWHQWA, _r4DWHQWA;
   reg                            r3DWHQWA, _r3DWHQWA;

   wire [127:0]                   wAlignBufMux;
   
   wire                           w3DWHInsBlank;
   wire                           w4DWHInsBlank;
   wire                           wOverflow;
   wire                           wSMLowEnable;
   wire                           wSMUpEnable;
   wire                           wTxStEopCondition;
   
   // Unconditional input capture
   always @(*) begin 
      _rTxStReady = (rTxStReady << 1) | TX_ST_READY;
   end

   always @(posedge CLK) begin
      rTxStReady <= _rTxStReady;
   end

   // Take data when: 
   assign wRegEn[0] = (~rTxDataValid | wRegEn[1]);
   assign wSMUpEnable = wRegEn[0];
   assign TX_DATA_READY = wRegEn[0];

   always @(*) begin 
      _rTxData = TX_DATA;
      _rTxTlpEndFlag = TX_TLP_END_FLAG & TX_DATA_VALID;
      _rTxTlpStartFlag = TX_TLP_START_FLAG & TX_DATA_VALID;
   end // always @ begin

   always @(posedge CLK) begin
      if(wRegEn[0]) begin
         rTxData <= _rTxData;
         rTxTlpEndFlag <= _rTxTlpEndFlag;
         rTxTlpStartFlag <= _rTxTlpStartFlag;
      end
   end
   
   always @(*) begin
      _r4DWH = rTxData[29] & rTxTlpStartFlag;
      _r3DWH = ~rTxData[29] & rTxTlpStartFlag;
      _rDataTLP = rTxData[30] & rTxTlpStartFlag;
      _rLenEven = ~rTxData[0] & rTxTlpStartFlag;
      _rLenOdd = rTxData[0] & rTxTlpStartFlag;

      _r4DWHQWA = ~TX_DATA[34] & rTxTlpStartFlag;
      _r3DWHQWA = ~TX_DATA[2] & rTxTlpStartFlag;
   end // always @ begin

   always @(posedge CLK) begin
      if(wRegEn[0]) begin
         r4DWH <= _r4DWH;
         r3DWH <= _r3DWH;
         rDataTLP <= _rDataTLP;
         rLenEven <= _rLenEven;
         rLenOdd <= _rLenOdd;
         r4DWHQWA <= _r4DWHQWA;
         r3DWHQWA <= _r3DWHQWA;
      end
   end
   
   // State machine for the upper pipeline
   // Valid never goes down inside of a TLP.
   always @(*) begin
      _rTxDataValid = rTxDataValid;

      if(wSMUpEnable & TX_DATA_VALID) begin //  & TX_TLP_START_FLAG
         _rTxDataValid = 1'b1;
      end else if ( wSMUpEnable & rTxTlpEndFlag)begin
         _rTxDataValid = 1'b0;
      end
      _rUpState = rUpState;
      case (rUpState)
        `S_TXALIGNER64UP_IDLE: begin
           if (TX_DATA_VALID & wSMUpEnable) begin
              _rUpState = `S_TXALIGNER64UP_HDR0;
           end
        end
        `S_TXALIGNER64UP_HDR0: begin
           if(wSMUpEnable) begin
              _rUpState = `S_TXALIGNER64UP_HDR1;
           end
        end
        `S_TXALIGNER64UP_HDR1: begin
           if(wSMUpEnable) begin
              casex ({rTxTlpEndFlag,TX_DATA_VALID})
                2'b0x: _rUpState = `S_TXALIGNER64UP_PAY;
                2'b10: _rUpState = `S_TXALIGNER64UP_IDLE; // No new TLP
                2'b11: _rUpState = `S_TXALIGNER64UP_HDR0;
              endcase // case (rTxTlpEndFlag)
           end
        end
        `S_TXALIGNER64UP_PAY : begin
           if(wSMUpEnable) begin
              casex ({rTxTlpEndFlag,TX_DATA_VALID})
                2'b0x: _rUpState = `S_TXALIGNER64UP_PAY;
                2'b10: _rUpState = `S_TXALIGNER64UP_IDLE; // No new TLP
                2'b11: _rUpState = `S_TXALIGNER64UP_HDR0;
              endcase // case (rTxTlpEndFlag)
           end
        end
      endcase // case (rUpState)
   end // always @ begin

   always @(posedge CLK) begin
      rTxDataValid <= _rTxDataValid;
      if(RST_IN) begin
         rUpState <= `S_TXALIGNER64UP_IDLE;
      end else begin
         rUpState <= _rUpState;
      end
   end // always @ (posedge CLK)

   assign wSMLowEnable = rTxStReady[C_TX_READY_LATENCY-1] | ~rTxStValid;
   assign wRegEn[1] = ~(rLowState == `S_TXALIGNER64LOW_PREOVFL & rTrigger) & (wSMLowEnable); 

   assign w3DWHInsBlank = rDataTLP & r3DWH & r3DWHQWA;
   assign w4DWHInsBlank = rDataTLP & r4DWH & ~r4DWHQWA;
   assign wOverflow = (w4DWHInsBlank & rLenEven) | (w3DWHInsBlank & rLenOdd);
   assign wAlignBufMux = ({{rTxData[31:0],rAlignBuffer[95:64]},rTxData[63:0]}) >> ({rSel,6'd0});

   always @(*) begin
      _rAlignBuffer = {rTxData[63:32], wAlignBufMux[63:0]};
   end // always @ begin

   always @(posedge CLK) begin
      if(wSMLowEnable) begin
         rAlignBuffer <= _rAlignBuffer; 
      end
   end

   assign wTxStEopCondition = (rLowState == `S_TXALIGNER64LOW_PREOVFL & rTrigger) | 
                              (rLowState != `S_TXALIGNER64LOW_PREOVFL & {rTxTlpEndFlag,wOverflow,rTxDataValid} == 3'b101);

   // Valid never goes down inside of a TLP.
   always @(*) begin
      _rLowState = rLowState;
      _rTrigger = rTrigger;
      _rTxStValid = rTxStValid;
      _rTxStEop = rTxStEop;
      _rTxStSop = rTxStSop;
      _rSel = rSel;

      _rTxStEop = wTxStEopCondition;
      _rTrigger = rTxDataValid & rTxTlpEndFlag;

      // Take the next txDataValid if we are taking data (wRegEn[1])
      // and it's a start flag and the data is valid
      if ( wRegEn[1] & rTxTlpStartFlag & rTxDataValid ) begin
         _rTxStValid = 1;
      end else if ( wSMLowEnable & rTxStEop | RST_IN ) begin
         _rTxStValid = 0;
      end

      if ( wRegEn[1] & rTxDataValid ) begin
         _rTxStSop = rTxTlpStartFlag;
      end else if ( wSMLowEnable | RST_IN) begin
         _rTxStSop = 0;
      end

      // rSel should be set on wInsBlank kept high until the end of the packet
      // Note: rSel is only applicable in multi-cycle packets
      if (wSMLowEnable & (w3DWHInsBlank | w4DWHInsBlank)) begin
         _rSel = 1'b1;
      end else if (wSMLowEnable & wTxStEopCondition | RST_IN) begin
         _rSel = 1'b0;
      end

      case (rLowState)
        `S_TXALIGNER64LOW_IDLE : begin
           if(wSMLowEnable) begin
              casex({rTxTlpEndFlag,wOverflow,rTxDataValid})     // Set the state for the next cycle
                3'bxx0: _rLowState = `S_TXALIGNER64LOW_IDLE;    // Stay here
                3'b001: _rLowState = `S_TXALIGNER64LOW_PROC;    // Process
                3'b011: _rLowState = `S_TXALIGNER64LOW_PREOVFL; // Don't set rTxStEop (set trigger)
                3'b101: _rLowState = `S_TXALIGNER64LOW_PROC;    // Set rTxStEop
                3'b111: _rLowState = `S_TXALIGNER64LOW_PREOVFL; // Don't set rTxStEop (set trigger)
              endcase
           end
        end
        `S_TXALIGNER64LOW_PROC : begin
           if(wSMLowEnable) begin
              casex({rTxTlpEndFlag,wOverflow,rTxDataValid})     // Set the state for the next cycle
                3'bxx0: _rLowState = `S_TXALIGNER64LOW_IDLE;    // If the next cycle is not valid Eop must have been set this cycle and we should go to idle
                3'b001: _rLowState = `S_TXALIGNER64LOW_PROC;    // Continue processing
                3'b011: _rLowState = `S_TXALIGNER64LOW_PREOVFL; // Don't set rTxStEop (set trigger)
                3'b101: _rLowState = `S_TXALIGNER64LOW_PROC;    // set rTxStEop 
                3'b111: _rLowState = `S_TXALIGNER64LOW_PREOVFL; // Don't set rTxStEop (set trigger)
              endcase
           end
        end
        `S_TXALIGNER64LOW_PREOVFL : begin
           if(wSMLowEnable) begin
              if(rTrigger) begin
                 _rLowState = `S_TXALIGNER64LOW_OVFL;
              end
           end
        end
        `S_TXALIGNER64LOW_OVFL : begin
           if(wSMLowEnable) begin
              casex({rTxTlpEndFlag,wOverflow,rTxDataValid})     // Set the state for the next cycle
                3'bxx0: _rLowState = `S_TXALIGNER64LOW_IDLE;    // If the next cycle is not valid Eop must have been set this cycle and we should go to idle
                3'b001: _rLowState = `S_TXALIGNER64LOW_PROC;    // Continue processing
                3'b011: _rLowState = `S_TXALIGNER64LOW_PREOVFL; // Don't set rTxStEop (Don't set trigger)
                3'b101: _rLowState = `S_TXALIGNER64LOW_PROC;    // set rTxStEop
                3'b111: _rLowState = `S_TXALIGNER64LOW_PREOVFL; // Don't set rTxStEop (set trigger)
              endcase
           end
        end
      endcase
   end // always @ begin
   
   always @(posedge CLK) begin
      if(RST_IN) begin
         rLowState <= `S_TXALIGNER64LOW_IDLE;
         rTxStValid <= 0;
         rTxStSop <= 0;
         rSel <= 0;
      end else begin
         rTxStValid <= _rTxStValid;
         rTxStSop <= _rTxStSop;
         rSel <= _rSel;
         rLowState <= _rLowState;
      end
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
   end // always @ (posedge CLK)

   // Outputs from the aligner to the PCIe Core
   assign TX_ST_VALID = (rTxStValid & rTxStReady[C_TX_READY_LATENCY-1]);
   assign TX_ST_EOP = rTxStEop;
   assign TX_ST_SOP = rTxStSop;
   assign TX_ST_EMPTY = 1'b0;
   assign TX_ST_DATA = rAlignBuffer[63:0];
endmodule
