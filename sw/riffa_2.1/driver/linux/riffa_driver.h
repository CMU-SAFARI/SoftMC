/*******************************************************************************
 * This software is Copyright © 2012 The Regents of the University of
 * California. All Rights Reserved.
 *
 * Permission to copy, modify, and distribute this software and its
 * documentation for educational, research and non-profit purposes, without fee,
 * and without a written agreement is hereby granted, provided that the above
 * copyright notice, this paragraph and the following three paragraphs appear in
 * all copies.
 *
 * Permission to make commercial use of this software may be obtained by
 * contacting:
 * Technology Transfer Office
 * 9500 Gilman Drive, Mail Code 0910
 * University of California
 * La Jolla, CA 92093-0910
 * (858) 534-5815
 * invent@ucsd.edu
 *
 * This software program and documentation are copyrighted by The Regents of the
 * University of California. The software program and documentation are supplied
 * "as is", without any accompanying services from The Regents. The Regents does
 * not warrant that the operation of the program will be uninterrupted or error-
 * free. The end-user understands that the program was developed for research
 * purposes and is advised not to rely exclusively on the program for any
 * reason.
 *
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO
 * ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR
 * CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING
 * OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
 * EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE. THE UNIVERSITY OF
 * CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 * THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS" BASIS,
 * AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATIONS TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
 * MODIFICATIONS.
 */

/*
 * Filename: riffa_driver.h
 * Version: 2.0
 * Description: Linux PCIe device driver for RIFFA. Uses Linux kernel APIs in
 *  version 2.6.27+ (tested on version 2.6.32 - 3.3.0).
 * Author: Matthew Jacobsen
 * History: @mattj: Initial release. Version 2.0.
 */

#ifndef RIFFA_DRIVER_H
#define RIFFA_DRIVER_H

#include <linux/ioctl.h>

#define DBUG 1

#ifdef DEBUG
#define DEBUG_MSG(...) printk(__VA_ARGS__)
#else
#define DEBUG_MSG(...)
#endif


// The major device number. We can't rely on dynamic registration because ioctls
// need to know it.
#define MAJOR_NUM 100
#define DEVICE_NAME "riffa"
#define VENDOR_ID0 0x10EE
#define VENDOR_ID1 0x1172

// Message events for readmsgs/writemsgs queues.
#define EVENT_TXN_LEN				1
#define EVENT_TXN_OFFLAST			2
#define EVENT_TXN_DONE				3
#define EVENT_SG_BUF_READ			4

// Constants and device offsets
#define NUM_FPGAS					5 	// max # of FPGAs to support in a single PC
#define MAX_CHNLS					12	// max # of channels per FPGA
#define MAX_BUS_WIDTH_PARAM			4	// max bus width parameter
#define SG_BUF_SIZE					(4*1024)	// size of shared SG buffer
#define SG_ELEMS					200 // # of SG elements to transfer at a time
#define SPILL_BUF_SIZE				(4*1024)	// size of shared spill common buffer

#define RX_SG_LEN_REG_OFF			0x0	// config offset for RX SG buf length
#define RX_SG_ADDR_LO_REG_OFF		0x1	// config offset for RX SG buf low addr
#define RX_SG_ADDR_HI_REG_OFF		0x2	// config offset for RX SG buf high addr
#define RX_LEN_REG_OFF				0x3	// config offset for RX txn length
#define RX_OFFLAST_REG_OFF			0x4	// config offset for RX txn last/offset
#define RX_TNFR_LEN_REG_OFF			0xD	// config offset for RX transfer length
#define TX_SG_LEN_REG_OFF			0x5	// config offset for TX SG buf length
#define TX_SG_ADDR_LO_REG_OFF		0x6	// config offset for TX SG buf low addr
#define TX_SG_ADDR_HI_REG_OFF		0x7	// config offset for TX SG buf high addr
#define TX_LEN_REG_OFF				0x8	// config offset for TX txn length
#define TX_OFFLAST_REG_OFF			0x9	// config offset for TX txn last/offset
#define TX_TNFR_LEN_REG_OFF			0xE	// config offset for TX transfer length

#define INFO_REG_OFF				0xA	// config offset for link info

#define IRQ_REG0_OFF				0xB	// config offset for interrupt reg 0
#define IRQ_REG1_OFF				0xC	// config offset for interrupt reg 1


// Structs
struct fpga_chnl_io
{
	int id;
	int chnl;
	unsigned int len;
	unsigned int offset;
	unsigned int last;
	unsigned long long timeout;
	char * data;
};
typedef struct fpga_chnl_io fpga_chnl_io;

struct fpga_info_list
{
	int num_fpgas;
	int id[NUM_FPGAS];
	int num_chnls[NUM_FPGAS];
	char name[NUM_FPGAS][16];
	int vendor_id[NUM_FPGAS];
	int device_id[NUM_FPGAS];
};
typedef struct fpga_info_list fpga_info_list;

// IOCTLs
#define IOCTL_SEND _IOW(MAJOR_NUM, 1, fpga_chnl_io *)
#define IOCTL_RECV _IOR(MAJOR_NUM, 2, fpga_chnl_io *)
#define IOCTL_LIST _IOR(MAJOR_NUM, 3, fpga_info_list *)
#define IOCTL_RESET _IOW(MAJOR_NUM, 4, int)



#endif
