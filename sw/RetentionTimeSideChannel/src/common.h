#ifndef SOFTMC_COMMON_H_
#define SOFTMC_COMMON_H_

#include <softmc.h>
#include <stdio.h>

//Default DRAM timing latencies
#define DEF_TRP 6
#define DEF_TCL 6
#define DEF_TBURST 4
#define DEF_TRCD 6


// Color code
#define RED "\x1b[31m"
#define GREEN "\x1b[32m"
#define YELLOW "\x1b[33m"
#define BLUE "\x1b[34m"
#define RESET "\x1b[0m"

// Debug macro code
#ifdef DEBUG
#define DEBUG_TEST 1
#else
#define DEBUG_TEST 0
#endif


#define debug_print(fmt, ...) \
        do { if (DEBUG_TEST) fprintf(stderr, "%s:%d:%s(): " fmt, __FILE__, \
                            __LINE__, __func__, ## __VA_ARGS__); } while (0)

#define detail_print(fmt, ...) \
        do { fprintf(stderr, "%s:%d:%s(): " fmt, __FILE__, \
                            __LINE__, __func__, ## __VA_ARGS__); } while (0)



// Row level
void writeRowFlexRCD(const uint row, const uint bank, uint8_t pattern,
                InstructionSequence*& iseq, const uint ncol, const uint trcd, const uint start_col,
                        const bool alternate_col_patt);
void writeRow(const uint row, const uint bank, uint8_t pattern,
                InstructionSequence*& iseq, const uint ncol);

int readAndCompareRow(const uint row, const uint bank,
                uint8_t pattern, InstructionSequence*& iseq, const uint ncol, const uint start_col, const bool alternate_col_patt);

int readAndCompareRow(const uint row, const uint bank,
                uint8_t pattern, InstructionSequence*& iseq, const uint ncol);

int recvAndCompare(uint8_t pattern, unsigned burst_errors[]);


#endif //SOFTMC_COMMON_H_
