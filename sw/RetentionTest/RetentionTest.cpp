#include <stdio.h>
#include <riffa.h>
#include <cassert>
#include <string.h>
#include <iostream>
#include <cmath>
#include "softmc.h"

using namespace std;

//Note that capacity of the instruction buffer is 8192 instructions
void writeRow(fpga_t* fpga, uint row, uint bank, uint8_t pattern, InstructionSequence*& iseq){

	if(iseq == nullptr)
		iseq = new InstructionSequence();
	else
		iseq->size = 0;//reuse the provided InstructionSequence to avoid dynamic allocation on each call

	//Precharge target bank (just in case if its left activated)
	iseq->insert(genPRE(bank, PRE_TYPE::SINGLE));

	//Wait for tRP
	iseq->insert(genWAIT(5));//2.5ns have already been passed as we issue in next cycle. So, 5 means 6 cycles latency, 15 ns

	//Activate target row
	iseq->insert(genACT(bank, row));

	//Wait for tRCD
	iseq->insert(genWAIT(5));

	//Write to the entire row
	for(int i = 0; i < NUM_COLS; i+=8){ //we use 8x burst mode
		iseq->insert(genWR(bank, i, pattern));

		//We need to wait for tCL and 4 cycles burst (double data-rate)
		iseq->insert(genWAIT(6 + 4));
	}

	//Wait some more in any case
	iseq->insert(genWAIT(3));

	//Precharge target bank
	iseq->insert(genPRE(bank, PRE_TYPE::SINGLE));

	//Wait for tRP
	iseq->insert(genWAIT(5));//we have already 2.5ns passed as we issue in next cycle. So, 5 means 6 cycles latency, 15 ns

	//START Transaction
	iseq->insert(genEND());

	iseq->execute(fpga);
}

void readAndCompareRow(fpga_t* fpga, const uint row, const uint bank, const uint8_t pattern, InstructionSequence*& iseq){

	if(iseq == nullptr)
		iseq = new InstructionSequence();
	else
		iseq->size = 0;//reuse the provided InstructionSequence to avoid dynamic allocation for each call

	//Precharge target bank (just in case if its left activated)
	iseq->insert(genPRE(bank, PRE_TYPE::SINGLE));

	//Wait for tRP
	iseq->insert(genWAIT(5));//2.5ns have already been passed as we issue in next cycle. So, 5 means 6 cycles latency, 15 ns

	//Activate target row
	iseq->insert(genACT(bank, row));

	//Wait for tRCD
	iseq->insert(genWAIT(5));

	//Read the entire row
	for(int i = 0; i < NUM_COLS; i+=8){ //we use 8x burst mode
		iseq->insert(genRD(bank, i));

		//We need to wait for tCL and 4 cycles burst (double data-rate)
		iseq->insert(genWAIT(6 + 4));
	}

	//Wait some more in any case
	iseq->insert(genWAIT(3));

	//Precharge target bank
	iseq->insert(genPRE(bank, PRE_TYPE::SINGLE)); //pre 1 -> precharge all, pre 0 precharge bank

	//Wait for tRP
	iseq->insert(genWAIT(5));//we have already 2.5ns passed as we issue in next cycle. So, 5 means 6 cycles latency, 15 ns

	//START Transaction
	iseq->insert(genEND());

	iseq->execute(fpga);

	//Receive the data
	uint rbuf[16];
	for(int i = 0; i < NUM_COLS; i+=8){ //we receive a single burst at two times (32 bytes each)
		fpga_recv(fpga, 0, (void*)rbuf, 16, 0);

		//compare with the pattern
		uint8_t* rbuf8 = (uint8_t *) rbuf;

		for(int j = 0; j < 64; j++){
			if(rbuf8[j] != pattern)
				fprintf(stderr, "Error at Col: %d, Row: %u, Bank: %u, DATA: %x \n", i, row, bank, rbuf8[j]);
		}
	}
}

void turnBus(fpga_t* fpga, BUSDIR b, InstructionSequence* iseq = nullptr){

	if(iseq == nullptr)
		iseq = new InstructionSequence();
	else
		iseq->size = 0;//reuse the provided InstructionSequence to avoid dynamic allocation for each call

	iseq->insert(genBUSDIR(b));

	//WAIT
	iseq->insert(genWAIT(5));

	//START Transaction
	iseq->insert(genEND());

	iseq->execute(fpga);	
}


//! Runs a test to check the DRAM cells against the given retention time.
/*!
  \param \e fpga is a pointer to the RIFFA FPGA device.
  \param \e retention is the retention time in milliseconds to test.
*/
void testRetention(fpga_t* fpga, const int retention){

	uint8_t pattern = 0xff; //the data pattern that we write to the DRAM

	bool dimm_done = false;

	InstructionSequence* iseq = nullptr; // we temporarily store (before sending them to the FPGA) the generated instructions here

	GET_TIME_INIT(2);

	//writing the entire row takes approximately 5 ms
	uint group_size = ceil(retention/5.0f); //number of rows to be written in a single iteration
	uint cur_row_write = 0;
	uint cur_bank_write = 0;
	uint cur_row_read = 0;
	uint cur_bank_read = 0;

    printf("\n");

	while(!dimm_done){ //continue until we cover the entire DRAM
		//print the number of the row that we are about to test
		printf("%c[2K\r", 27);
        printf("Current Bank: %d, Row: %d", cur_bank_write, cur_row_write);
		fflush(stdout);
        
		// Switch the memory bus to write mode
		turnBus(fpga, BUSDIR::WRITE, iseq);

		GET_TIME_VAL(0);

		// We write to a chunk of rows (group_size) successively
		for(int i = 0; i < group_size; i++){
			// write the data pattern to the entire row
			writeRow(fpga, cur_row_write, cur_bank_write, pattern, iseq);
			cur_row_write++;

			// when we complete testing all of the rows in a bank, we move to the next bank
			if(cur_row_write == NUM_ROWS){
				cur_row_write = 0;
				cur_bank_write++;
			}
		
			// the entire DIMM is covered when we complete testing all of the bank
			if(cur_bank_write == NUM_BANKS){
				// we are done with the entire DIMM
				dimm_done = true;
				break;
			}
		}

		// Switch the memory bus to read mode
		turnBus(fpga, BUSDIR::READ, iseq);

		// wait for the specified retention time (retention)
		do{
			GET_TIME_VAL(1);
		} while((TIME_VAL_TO_MS(1) - TIME_VAL_TO_MS(0)) < retention);

		// Read the data back and compare
		for(int i = 0; i < group_size; i++){
			readAndCompareRow(fpga, cur_row_read, cur_bank_read, pattern, iseq);

			cur_row_read++;

			if(cur_row_read == NUM_ROWS){ //NUM_ROWS
				cur_row_read = 0;
				cur_bank_read++;
			}
		
			if(cur_bank_read == NUM_BANKS){ //NUM_BANKS
				//we are done with the entire DIMM
				break;
			}
		}
	}

	printf("\n");

	delete iseq;
}

// provide trefi = 0 to disable auto-refresh
// auto-refresh is disabled by default (disabled after FPGA boots, disables on pushing reset button)
void setRefreshConfig(fpga_t* fpga, uint trefi, uint trfc){
	InstructionSequence* iseq = new InstructionSequence;

	iseq->insert(genREF_CONFIG(trfc, REGISTER::TRFC));
	iseq->insert(genREF_CONFIG(trefi, REGISTER::TREFI));

	//START Transaction
	iseq->insert(genEND());

	iseq->execute(fpga);	

	delete iseq;
}


void printHelp(char* argv[]){
	cout << "A sample application that tests retention time of DRAM cells using SoftMC" << endl;
	cout << "Usage:" << argv[0] << " [REFRESH INTERVAL]" << endl; 
	cout << "The Refresh Interval should be a positive integer, indicating the target retention time in milliseconds." << endl;
}

int main(int argc, char* argv[]){
	fpga_t* fpga;
	fpga_info_list info;
	int fid = 0; //fpga id
	int ch = 0; //channel id

	if(argc != 2 || strcmp(argv[1], "--help") == 0){
		printHelp(argv);
		return -2;
	}

    string s_ref(argv[1]);
    int refresh_interval = 0;

    try{
        refresh_interval = stoi(s_ref);    
    }catch(...){
        printHelp(argv);
        return -3;
    }

    if(refresh_interval <= 0){
        printHelp(argv);
        return -4;
    }

	// Get the list of FPGA's attached to the system
	if (fpga_list(&info) != 0) {
		printf("Error populating fpga_info_list\n");
		return -1;
	}
	printf("Number of devices: %d\n", info.num_fpgas);
	for (int i = 0; i < info.num_fpgas; i++) {
		printf("%d: id:%d\n", i, info.id[i]);
		printf("%d: num_chnls:%d\n", i, info.num_chnls[i]);
		printf("%d: name:%s\n", i, info.name[i]);
		printf("%d: vendor id:%04X\n", i, info.vendor_id[i]);
		printf("%d: device id:%04X\n", i, info.device_id[i]);
	}

	// Open an FPGA device, so we can read/write from/to it
	fpga = fpga_open(fid);

	if(!fpga){
		printf("Problem on opening the fpga \n");
		return -1;
	}
	printf("The FPGA has been opened successfully! \n");

	// send a reset signal to the FPGA
	fpga_reset(fpga); //keep this, recovers FPGA from some unwanted state

	//uint trefi = 7800/200; //7.8us (divide by 200ns as the HW counts with that period)
	//uint trfc = 104; //default trfc for 4Gb device
	//printf("Activating AutoRefresh. tREFI: %d, tRFC: %d \n", trefi, trfc);
	//setRefreshConfig(fpga, trefi, trfc);

  	printf("Starting Retention Time Test @ %d ms! \n", refresh_interval);

	testRetention(fpga, refresh_interval);

	printf("The test has been completed! \n");
	fpga_close(fpga);

	return 0;
}
