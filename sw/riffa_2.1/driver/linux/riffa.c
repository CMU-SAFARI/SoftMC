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
 * Filename: riffa.c
 * Version: 2.0
 * Description: Linux PCIe communications API for RIFFA.
 * Author: Matthew Jacobsen
 * History: @mattj: Initial release. Version 2.0.
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <fcntl.h>
#include "riffa.h"

struct fpga_t
{
	int fd;
	int id;
};

fpga_t * fpga_open(int id) 
{
	fpga_t * fpga;

	// Allocate space for the fpga_dev
	fpga = (fpga_t *)malloc(sizeof(fpga_t));
	if (fpga == NULL)
		return NULL;
	fpga->id = id;	

	// Open the device file.
	fpga->fd = open("/dev/" DEVICE_NAME, O_RDWR | O_SYNC);
	if (fpga->fd < 0) {
		free(fpga); 
		return NULL;
	}
	
	return fpga;
}

void fpga_close(fpga_t * fpga) 
{
	// Close the device file.
	close(fpga->fd);
	free(fpga);
}

int fpga_send(fpga_t * fpga, int chnl, void * data, int len, int destoff, 
	int last, long long timeout)
{
	fpga_chnl_io io;

	io.id = fpga->id;
	io.chnl = chnl;
	io.len = len;
	io.offset = destoff;
	io.last = last;
	io.timeout = timeout;
	io.data = (char *)data;

	return ioctl(fpga->fd, IOCTL_SEND, &io);
}

int fpga_recv(fpga_t * fpga, int chnl, void * data, int len, long long timeout)
{
	fpga_chnl_io io;

	io.id = fpga->id;
	io.chnl = chnl;
	io.len = len;
	io.timeout = timeout;
	io.data = (char *)data;

	return ioctl(fpga->fd, IOCTL_RECV, &io);
}

void fpga_reset(fpga_t * fpga)
{
	ioctl(fpga->fd, IOCTL_RESET, fpga->id);
}

int fpga_list(fpga_info_list * list) {
	int fd;
	int rc;

	fd = open("/dev/" DEVICE_NAME, O_RDWR | O_SYNC);
	if (fd < 0)
		return fd;
	rc = ioctl(fd, IOCTL_LIST, list);
	close(fd);
	return rc;
}



