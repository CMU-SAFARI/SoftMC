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
 * Filename: circ_queue.h
 * Version: 1.0
 * Description: A lock-free single-producer circular queue implementation 
 *   modeled after the more elaborate C++ version from Faustino Frechilla at:
 *   http://www.codeproject.com/Articles/153898/Yet-another-implementation-of-a-lock-free-circular
 * Author: Matthew Jacobsen
 * History: @mattj: Initial release. Version 1.0.
 */
#ifndef CIRC_QUEUE_H
#define CIRC_QUEUE_H

#include <asm/atomic.h>

/* Struct for the circular queue. */
struct circ_queue {
	atomic_t writeIndex;
	atomic_t readIndex;
	unsigned int ** vals;
	unsigned int len;
};
typedef struct circ_queue circ_queue;

/**
 * Initializes a circ_queue with depth/length len. Returns non-NULL on success, 
 * NULL if there was a problem creating the queue.
 */
circ_queue * init_circ_queue(int len);

/**
 * Pushes a pair of unsigned int values into the specified queue at the head. 
 * Returns 0 on success, non-zero if there is no more space in the queue.
 */
int push_circ_queue(circ_queue * q, unsigned int val1, unsigned int val2);

/**
 * Pops a pair of unsigned int values out of the specified queue from the tail.
 * Returns 0 on success, non-zero if the queue is empty.
 */
int pop_circ_queue(circ_queue * q, unsigned int * val1, unsigned int * val2);

/**
 * Returns 1 if the circ_queue is empty, 0 otherwise. Note, this is not a 
 * synchronized function. If another thread is accessing this circ_queue, the
 * return value may not be valid.
 */
int circ_queue_empty(circ_queue * q);

/**
 * Returns 1 if the circ_queue is full, 0 otherwise. Note, this is not a 
 * synchronized function. If another thread is accessing this circ_queue, the
 * return value may not be valid.
 */
int circ_queue_full(circ_queue * q);

/**
 * Frees the resources associated with the specified circ_queue.
 */
void free_circ_queue(circ_queue * q);

#endif
