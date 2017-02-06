#ifndef SOFTMC_H
#define SOFTMC_H

#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <vector>
#include <sys/time.h>
#include <riffa.h>

#define GET_TIME_INIT(num) struct timeval _timers[num]

#define GET_TIME_VAL(num) gettimeofday(&_timers[num], NULL)

#define TIME_VAL_TO_MS(num) (((double)_timers[num].tv_sec*1000.0) + ((double)_timers[num].tv_usec/1000.0))


#define BANK_OFFSET 3
#define ROW_OFFSET 16
#define CMD_OFFSET 4
#define COL_OFFSET 10
#define SIGNAL_OFFSET 6

// The current instruction format is 32 bits wide. But we allocate
// 64 bits (2 words) for each instruction to keep the hardware simple.
// Having C_PCI_DATA_WIDTH of 64 performs better than 32 when sending
// data that we read from the DRAM back to the host machine.
// TODO: modify the hardware to support 32-bit instructions.
#define INSTR_SIZE 2 //2 words

#define NUM_ROWS 32768
#define NUM_COLS 1024
#define NUM_BANKS 8

typedef uint64_t Instruction;
typedef uint32_t uint;

//DO NOT EDIT (unless you change the verilog code)
enum class INSTR_TYPE {
	END_OF_INSTRS = 0,
	SET_BUS_DIR = 1,
	WAIT = 4,
	DDR = 8
};
//END - DO NOT EDIT

enum class BUSDIR {
	READ = 0,
	WRITE = 2
};

enum class AUTO_PRECHARGE {
	NO_AP = 0,
	AP = 1
};

enum class PRE_TYPE {
	SINGLE = 0,
	ALL = 1
};

enum class BURST_LENGTH {
	CHOP = 0,
	FIXED = 1
};

enum class REGISTER {
	TREFI = 2,
	TRFC = 3
};


class InstructionSequence{

	public:
		InstructionSequence();
		InstructionSequence(const uint capacity);
		virtual ~InstructionSequence();

		void insert(const Instruction c);
		void execute(fpga_t* fpga);

		uint size;
		Instruction* instrs;
	private:
		uint capacity;
		const static uint init_cap = 256;
};


class DramAddr{

	public:
		uint row;
		uint bank;

		DramAddr() : DramAddr(0, 0){}
		DramAddr(uint row, uint bank){ this->row = row; this->bank = bank;}
};

Instruction genACT(uint bank, uint row);
Instruction genPRE(uint bank, PRE_TYPE pt = PRE_TYPE::SINGLE);
Instruction genWR(uint bank, uint col, uint8_t pattern, AUTO_PRECHARGE ap = AUTO_PRECHARGE::NO_AP, BURST_LENGTH bl = BURST_LENGTH::FIXED);
Instruction genRD(uint bank, uint col, AUTO_PRECHARGE ap = AUTO_PRECHARGE::NO_AP, BURST_LENGTH bl = BURST_LENGTH::FIXED);
Instruction genWAIT(uint cycles);
Instruction genBUSDIR(BUSDIR dir);
Instruction genEND();
Instruction genZQ();
Instruction genREF();
Instruction genREF_CONFIG(uint val, REGISTER r);


#endif //SOFTMC_H
