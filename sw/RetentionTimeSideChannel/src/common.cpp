#include "common.h"
#include <cassert>

// Global Variables
// // # of bits flipping from 0->1 and 1->0
int toggle01 = 0;
int toggle10 = 0;

/**
 * @brief Write a single pattern to every cache line in a specified row.
 *
 * @alternate_col_patt invert the pattern every other column. Even col is always
 * pattern and odd col is always ~pattern.
 **/
void writeRowFlexRCD(const uint row, const uint bank, uint8_t pattern,
        InstructionSequence*& iseq, const uint ncol, const uint trcd, const uint start_col,
        const bool alternate_col_patt)
{

    //Precharge target bank (just in case if its left activated)
    iseq->genPRE(bank, PRE_TYPE::SINGLE);
    iseq->genWAIT(DEF_TRP); //Wait for tRP
    iseq->genACT(bank, row); //Activate target row

    // -1 due to the elapse time of the cmd issue cycle
    if (trcd > 1)
        iseq->genWAIT(trcd - 1);

    // adjust the first pattern being written based on the first col location
    if (alternate_col_patt)
        pattern = ((start_col/8) % 2 == 0) ? pattern : (uint8_t)~pattern;

    //Write to some columns in a row
    for(int i = start_col; i < (ncol+start_col); i+=8) {
        iseq->genWR(bank, i, pattern);
        iseq->genWAIT(DEF_TCL + DEF_TBURST);
        if (alternate_col_patt)
            pattern = (uint8_t)~pattern;
    }

    iseq->genWAIT(3); //Wait some more in any case
    iseq->genPRE(bank, PRE_TYPE::SINGLE); //Precharge target bank
    iseq->genWAIT(DEF_TRP); //Wait for tRP

	iseq->execute();
}


/**
 * @brief Write a single pattern to every cache line in a specified row with
 * the default tRCD value and use a single pattern
 **/
void writeRow(const uint row, const uint bank, uint8_t pattern,
                        InstructionSequence*& iseq, const uint ncol){

	writeRowFlexRCD(row, bank, pattern, iseq, ncol, DEF_TRCD, 0, false);
}

/**
 * @brief Read N cache lines from a row and compare it to the written value
 *
 * @alternate_col_patt invert the pattern every other column. Even col is always
 * pattern and odd col is always ~pattern.
 **/
int readAndCompareRow(const uint row, const uint bank,
        uint8_t pattern, InstructionSequence*& iseq, const uint ncol, const uint start_col,
        const bool alternate_col_patt)
{
    //Precharge target bank (just in case if its left activated)
    iseq->genPRE(bank, PRE_TYPE::SINGLE);
    iseq->genWAIT(DEF_TRP); //Wait for tRP
    iseq->genACT(bank, row); //Activate target row
    iseq->genWAIT(DEF_TRCD-1); //Wait for tRCD

    //Read the entire row
    for(int i = start_col; i < (ncol+start_col); i+=8) {
        iseq->genRD(bank, i);
        iseq->genWAIT(DEF_TCL + DEF_TBURST);
    }

    iseq->genWAIT(3); //Wait some more in any case
    iseq->genPRE(bank, PRE_TYPE::SINGLE); //Precharge target bank
    iseq->genWAIT(DEF_TRP); //Wait for tRP

    // START Transaction
	iseq->execute();

    // Compare each cache line's result
    int total_bit_error = 0;
    bool fpga_err = false;
    // adjust the first pattern being read based on the first col location
    if (alternate_col_patt)
        pattern = ((start_col/8) % 2 == 0) ? pattern : (uint8_t)~pattern;

    for(int i = 0; i < ncol; i+=8) {
        //Receive the data
        unsigned burst_errors[8] = {0,0,0,0,0,0,0,0} ;
        int err_cnt = recvAndCompare(pattern, burst_errors) ;
        if (err_cnt > 0) {
            total_bit_error += err_cnt;
            debug_print("RdCmp Error at Col: %d, Row: %u, Bank: %u, cnt: %d \n",
                    i, row, bank, err_cnt);
        }
        else if (-1 == err_cnt) {
            fpga_err = true; 
            detail_print(RED "FPGA Error at Col: %d, Row: %u, Bank: %u\n" RESET, i, row, bank);
        }
        if (alternate_col_patt)
            pattern = (uint8_t)~pattern;
    }
    return fpga_err ? -1 : total_bit_error;
}


/**
 * @brief Read N cache lines from a row and compare it to the written value
 **/
int readAndCompareRow(const uint row, const uint bank,
                        uint8_t pattern, InstructionSequence*& iseq, const uint ncol){

	return readAndCompareRow(row, bank, pattern, iseq, ncol, 0, true);
}

/**
 * @brief Transfer the read cache line from the FPGA to the host machine and
 * store it in a buffer (size 16 32-bit elements => 512 bits => 64 bytes). Then
 * compare the read data with the written pattern.
 *
 * @burst_errors store the number bit flips in each transfer (eight in total)
 * in a data burst
 **/
int recvAndCompare(uint8_t pattern, unsigned burst_errors[])
{
    //uint rbuf[16];
    uint rbuf[32]; // use a bigger (2x) buffer size

    int num_recv = 0 ;
    //num_recv = fpga_recv(fpga, ch, (void*)rbuf, 16, 1000);
    num_recv = SoftMCPlatform::receiveData((void*)rbuf, 32, 1000);
    if (num_recv != 16)
    {
        detail_print(RED "Received %d words instead of 16.\n" RESET, num_recv);
        return -1 ;
    }

    uint8_t* rbuf8 = (uint8_t *) rbuf;
    int err_cnt = 0;

    // Compare the data pattern to each transfer of a data burst
    for(int j = 0; j < 8; j++) {
        int burst_error_cnt = 0 ;
        for (int k = 0; k < 8; k++) {
            uint8_t diff = rbuf8[8*j+k] ^ pattern;
            uint8_t pattern_copy = pattern;
            for (int ci = 0; ci < 8; ci++) {
                err_cnt += (diff & 1);
                burst_error_cnt += (diff & 1);
                if (pattern_copy & 1)
                  toggle10 += (diff & 1); //1 to 0 toggle
                else
                  toggle01 += (diff & 1); //0 to 1 toggle
                pattern_copy >>= 1;
                diff >>= 1;
            }
        }
        burst_errors[j] += burst_error_cnt ;
    }
    // A cache line is only 64 bytes (512 bits)
    assert(err_cnt <= 512);
    return err_cnt;
}

