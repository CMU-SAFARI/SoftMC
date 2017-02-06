
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
// File       : pcie_bram_top_v6.v
// Version    : 2.4
//--
//-- Description: BlockRAM top level module for Virtex6 PCIe Block
//--
//--
//--
//--------------------------------------------------------------------------------

`timescale 1ns/1ns

module pcie_bram_top_v6
#(
   parameter DEV_CAP_MAX_PAYLOAD_SUPPORTED = 0,

   parameter VC0_TX_LASTPACKET         = 31,
   parameter TLM_TX_OVERHEAD           = 24,
   parameter TL_TX_RAM_RADDR_LATENCY   = 1,
   parameter TL_TX_RAM_RDATA_LATENCY   = 2,
   parameter TL_TX_RAM_WRITE_LATENCY   = 1,

   parameter VC0_RX_LIMIT              = 'h1FFF,
   parameter TL_RX_RAM_RADDR_LATENCY   = 1,
   parameter TL_RX_RAM_RDATA_LATENCY   = 2,
   parameter TL_RX_RAM_WRITE_LATENCY   = 1
)
  (
   input          user_clk_i,
   input          reset_i,

   input          mim_tx_wen,
   input  [12:0]  mim_tx_waddr,
   input  [71:0]  mim_tx_wdata,
   input          mim_tx_ren,
   input          mim_tx_rce,
   input  [12:0]  mim_tx_raddr,
   output [71:0]  mim_tx_rdata,

   input          mim_rx_wen,
   input  [12:0]  mim_rx_waddr,
   input  [71:0]  mim_rx_wdata,
   input          mim_rx_ren,
   input          mim_rx_rce,
   input  [12:0]  mim_rx_raddr,
   output [71:0]  mim_rx_rdata
   );

   // TX calculations
   localparam MPS_BYTES = ((DEV_CAP_MAX_PAYLOAD_SUPPORTED == 0) ? 128 :
                           (DEV_CAP_MAX_PAYLOAD_SUPPORTED == 1) ? 256 :
                           (DEV_CAP_MAX_PAYLOAD_SUPPORTED == 2) ? 512 :
                                                                 1024 );

   localparam BYTES_TX = (VC0_TX_LASTPACKET + 1) * (MPS_BYTES + TLM_TX_OVERHEAD);

   localparam ROWS_TX = 1;
   localparam COLS_TX = ((BYTES_TX <= 4096) ?  1 :
                         (BYTES_TX <= 8192) ?  2 :
                         (BYTES_TX <= 16384) ? 4 :
                         (BYTES_TX <= 32768) ? 8 :
                                              18
                        );

   // RX calculations
   localparam ROWS_RX = 1;

   localparam COLS_RX = ((VC0_RX_LIMIT < 'h0200) ? 1 :
                         (VC0_RX_LIMIT < 'h0400) ? 2 :
                         (VC0_RX_LIMIT < 'h0800) ? 4 :
                         (VC0_RX_LIMIT < 'h1000) ? 8 :
                                                  18
                        );

   initial begin
      $display("[%t] %m ROWS_TX %0d COLS_TX %0d", $time, ROWS_TX, COLS_TX);
      $display("[%t] %m ROWS_RX %0d COLS_RX %0d", $time, ROWS_RX, COLS_RX);
   end

   pcie_brams_v6 #(.NUM_BRAMS        (COLS_TX),
                   .RAM_RADDR_LATENCY(TL_TX_RAM_RADDR_LATENCY),
                   .RAM_RDATA_LATENCY(TL_TX_RAM_RDATA_LATENCY),
                   .RAM_WRITE_LATENCY(TL_TX_RAM_WRITE_LATENCY))
   pcie_brams_tx
   (
    .user_clk_i(user_clk_i),
    .reset_i(reset_i),

    .waddr(mim_tx_waddr),
    .wen(mim_tx_wen),
    .ren(mim_tx_ren),
    .rce(mim_tx_rce),
    .wdata(mim_tx_wdata),
    .raddr(mim_tx_raddr),
    .rdata(mim_tx_rdata)
   );

   pcie_brams_v6 #(.NUM_BRAMS        (COLS_RX),
                   .RAM_RADDR_LATENCY(TL_RX_RAM_RADDR_LATENCY),
                   .RAM_RDATA_LATENCY(TL_RX_RAM_RDATA_LATENCY),
                   .RAM_WRITE_LATENCY(TL_RX_RAM_WRITE_LATENCY))
   pcie_brams_rx
   (
    .user_clk_i(user_clk_i),
    .reset_i(reset_i),

    .waddr(mim_rx_waddr),
    .wen(mim_rx_wen),
    .ren(mim_rx_ren),
    .rce(mim_rx_rce),
    .wdata(mim_rx_wdata),
    .raddr(mim_rx_raddr),
    .rdata(mim_rx_rdata)
   );

endmodule // pcie_bram_top
