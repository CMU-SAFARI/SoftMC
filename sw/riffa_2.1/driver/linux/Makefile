# This software is Copyright © 2012 The Regents of the University of 
# California. All Rights Reserved.
# 
# Permission to copy, modify, and distribute this software and its 
# documentation for educational, research and non-profit purposes, without fee, 
# and without a written agreement is hereby granted, provided that the above 
# copyright notice, this paragraph and the following three paragraphs appear in
# all copies.
# 
# Permission to make commercial use of this software may be obtained by 
# contacting:
# Technology Transfer Office
# 9500 Gilman Drive, Mail Code 0910
# University of California
# La Jolla, CA 92093-0910
# (858) 534-5815
# invent@ucsd.edu
# 
# This software program and documentation are copyrighted by The Regents of the
# University of California. The software program and documentation are supplied
# "as is", without any accompanying services from The Regents. The Regents does
# not warrant that the operation of the program will be uninterrupted or error-
# free. The end-user understands that the program was developed for research 
# purposes and is advised not to rely exclusively on the program for any 
# reason.
# 
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO
# ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR
# CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING
# OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE. THE UNIVERSITY OF
# CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, 
# AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATIONS TO
# PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.

# Filename: Makefile
# Version: 2.0
# Description: Makefile for Linux PCIe device driver for RIFFA.
# Author: Matthew Jacobsen
# History: @mattj: Initial release. Version 2.0.

# You must specify the following variables. You can leave the defaults if you
# like, but make sure they will work in your system.
# The VENDOR_ID _must_ match what is configured on your FPGA's PCIe endpoint 
# header. Xilinx has a VENDOR_ID = 10EE.
NAME := riffa
VENDOR_ID0 := 10EE
VENDOR_ID1 := 1172
MAJNUM := 100

# Build variables
KVER := $(shell uname -r)
KDIR := /lib/modules/`uname -r`/build
RHR := /etc/redhat-release
LIB_SRCS := riffa.c
LIB_OBJS := $(patsubst %.c,%.o,$(LIB_SRCS))
LIB_HDR := riffa.h
LIB_VER_MAJ := 1
LIB_VER_MIN := 0
LIB_VER := $(LIB_VER_MAJ).$(LIB_VER_MIN)
DRVR_HDR := riffa_driver.h
DBUGVAL := DBUG

obj-m += $(NAME).o
$(NAME)-y := riffa_driver.o circ_queue.o

# Helper functions
define assert
  $(if $1,,$(error Assertion failed: $2))
endef
define assert-not-null
  $(call assert,$($1),The variable "$1" is null, please specify it.)
endef
define assert-variables
	$(call assert-not-null,NAME)
	$(call assert-not-null,MAJNUM)
	$(call assert-not-null,VENDOR_ID0)
	$(call assert-not-null,VENDOR_ID1)
	@printf "Compiling driver for kernel: %s with the following values\n" $(KVER)
	@printf "     NAME: '%s'\n" $(NAME)
	@printf "   MAJNUM: '%s'\n" $(MAJNUM)
	@printf "VENDOR_ID0: '%s'\n" $(VENDOR_ID0)
	@printf "VENDOR_ID1: '%s'\n" $(VENDOR_ID1)
	@printf "\n"
endef

all: builddvr
debug: CC += -DDEBUG -g -Wno-error-implicit-function-declaration
debug: DBUGVAL = DEBUG
debug: builddvr
builddvr: $(NAME).ko $(NAME).so.$(LIB_VER)

$(NAME).ko: *.c *.h
	$(call assert-variables)
	sed -i 's/#define MAJOR_NUM [^\n]*/#define MAJOR_NUM $(MAJNUM)/g' $(DRVR_HDR)
	sed -i 's/#define DEVICE_NAME [^\n]*/#define DEVICE_NAME "$(NAME)"/g' $(DRVR_HDR)
	sed -i 's/#define VENDOR_ID0 [^\n]*/#define VENDOR_ID0 0x$(VENDOR_ID0)/g' $(DRVR_HDR)
	sed -i 's/#define VENDOR_ID1 [^\n]*/#define VENDOR_ID1 0x$(VENDOR_ID1)/g' $(DRVR_HDR)
	sed -i 's/#define DEBUG [^\n]*/#define DBUG 1/g' $(DRVR_HDR)
	sed -i 's/#define DBUG [^\n]*/#define $(DBUGVAL) 1/g' $(DRVR_HDR)
	make -C $(KDIR) SUBDIRS=`pwd` modules
	rm -rf $(LIB_OBJS)

$(NAME).so.$(LIB_VER): $(LIB_OBJS)
	$(CC) -shared -Wno-error-implicit-function-declaration,-soname,lib$(NAME).so.$(LIB_VER_MAJ) -o lib$@ $^

$(LIB_OBJS): $(LIB_SRCS)
	$(CC) -g -Wall -fPIC -c $^

load: $(NAME).ko
	insmod $(NAME).ko
	
unload:
	rmmod $(NAME)

clean:
	rm -Rf *.ko *.cmd *.o *.so *.so.* .*.cmd Module.symvers Module.markers modules.order *.mod.c .tmp_versions

setup:
	if [ -f "$(RHR)" ]; then yum install kernel-devel-`uname -r`;\
	else apt-get install linux-headers-`uname -r`; fi

install: $(NAME).so.$(LIB_VER) $(NAME).ko 
	mkdir -p /lib/modules/$(KVER)/kernel/drivers/$(NAME)
	cp $(NAME).ko /lib/modules/$(KVER)/kernel/drivers/$(NAME)/
	if [ -f "$(RHR)" ]; then\
		printf "%b\n" "#!/bin/sh\nexec /sbin/modprobe $(NAME) >/dev/null 2>&1" > /etc/sysconfig/modules/$(NAME).modules;\
		chmod 755 /etc/sysconfig/modules/$(NAME).modules;\
	else\
		if ! grep -Fxq "$(NAME)" /etc/modules; then echo "$(NAME)" >> /etc/modules; fi;\
	fi
	printf "%b\n" "KERNEL==\"$(NAME)\", MODE=\"777\", GROUP=\"root\"" > /etc/udev/rules.d/99-$(NAME).rules
	printf "/usr/local/lib\n" > $(NAME).conf
	mv $(NAME).conf /etc/ld.so.conf.d/
	cp $(DRVR_HDR) /usr/local/include/
	cp $(LIB_HDR) /usr/local/include/
	mv lib$(NAME).so.1.0 /usr/local/lib
	ln -sf /usr/local/lib/lib$(NAME).so.$(LIB_VER) /usr/local/lib/lib$(NAME).so.$(LIB_VER_MAJ)
	ln -sf /usr/local/lib/lib$(NAME).so.$(LIB_VER) /usr/local/lib/lib$(NAME).so
	ldconfig
	depmod

uninstall: 
	rm -f /usr/local/lib/lib$(NAME).so*
	rm -f /usr/local/include/$(LIB_HDR)
	rm -f /usr/local/include/$(DRVR_HDR)
	rm -f /etc/ld.so.conf.d/$(NAME).conf
	rm -rf /lib/modules/$(KVER)/kernel/drivers/$(NAME)
	rm -f /etc/udev/rules.d/99-$(NAME).rules
	if [ -f "$(RHR)" ]; then rm -f /etc/sysconfig/modules/$(NAME).modules;\
	else cp /etc/modules ./etc.modules.bak; sed -i '/$(NAME)/d' /etc/modules; fi
	ldconfig
	depmod


