To install RIFFA 2.0, find the instructions in the install directory for your
os. The source directory contains all the source code for the drivers, sample
applications, etc.

You can get started with your HDL design using a sample from the FPGA directory.
It contains example HDL designs with corresponding example software.

For further details, see the RIFFA 2.0 website at:
http://cseweb.ucsd.edu/~mdjacobs 


Release notes:

Version 2.0.2
-------------

- Fixed: Bug in Windows and Linux drivers that could report data sent/received 
  before such data was confirmed.

- Fixed: Updated common functions to avoid assigning input values.

- Fixed: FIFO overflow error causing data corruption in tx_engine_upper and
  breaking the Xilinx Endpoint.

- Fixed: Missing default cases in rx_port_reader, sg_list_requester, 
  tx_engine_upper, and tx_port_writer.

- Fixed: Bug in tx_engine_lower_128 corrupting s_axis_tx_tkeep, causing Xilinx
  PCIe endpoint core to shut down.

- Fixed: Bug in tx_engine_upper_128 causing incomplete TX data timeouts.

- Changed rx_engine to not block on non-posted TLPs. They're added to a FIFO and
  serviced in order. 

- Reset rx_port FIFOs before a receive transaction to avoid data corruption from
  replayed TLPs.

Version 2.0.1
-------------

- RIFFA 2.0.1 is a general release. This means we've tested it in a number of
  ways. Please let us know if you encounter a bug. 

- Neither the HDL nor the drivers from RIFFA 2.0.1 are backwards compatible with
  the components of any previous release of RIFFA.

- RIFFA 2.0.1 consumes more resources than 2.0 beta. This is because 2.0.1 was
  rewritten to support scatter gather DMA, higher bandwidth, and appreciably 
  more signal registering. The additional registering was included to help meet 
  timing constraints. 

- The Windows driver is supported on Windows 7 32/64. Other Windows versions 
  can be supported. The driver simply needs to be built for that target.

- Debugging on Windows is difficult because there exists no system log file.
  Driver log messages are visible only to an attached kernel debugger. So to see
  any messages you'll need the Windows Development Kit debugger (WinDbg) or a 
  small utility called DbgView. DbgView is a standalone kernel debug viewer that
  can be downloaded from Microsoft here:
  http://technet.microsoft.com/en-us/sysinternals/bb896647.aspx
  Run DbgView with administrator privileges and be sure to enable the following
  capture options: Capture Kernel, Capture Events, and Capture Verbose Kernel 
  Output.

- The Linux driver is supported on kernel version 2.6.27+. 

- The Java bindings make use of a native library (in order to connect Java JNI
  to the native library). Libraries for Linux and Windows for both 32/64 bit 
  platforms have been compiled and included in the riffa.jar.

- Removed the CHNL_RX_ERR signal from the channel interface. Error handling now
  ends the transaction gracefully. Errors can be easily detected by comparing
  the number of words received to the CHNL_RX_LEN amount. An error will cause
  CHNL_RX will go low prematurely and not provide the advertised amount of data.

- Fixed: Bug in sg_list_requester which could cause an unbounded TLP request.

- Fixed: Bug in tx_port_buffer_128 which could stall the TX transaction.

