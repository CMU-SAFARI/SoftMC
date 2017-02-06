#include "softmc.h"
#include <fstream>
#include <iostream>
#include <cassert>

using namespace std;

InstructionSequence::InstructionSequence() : InstructionSequence(init_cap){
}

InstructionSequence::InstructionSequence(const uint capacity){
	instrs = new Instruction[capacity];
	size = 0;
	this->capacity = capacity;
}

InstructionSequence::~InstructionSequence(){
	delete[] instrs;
}

void InstructionSequence::insert(const Instruction c){
	if(size == capacity){
		Instruction* tmp = new Instruction[capacity*2];
		
		for(int i = 0; i < size; i++)
			tmp[i] = instrs[i];

		delete[] instrs;
		capacity *=2;
		instrs = tmp;
	}

	instrs[size++] = c;
}

void InstructionSequence::execute(fpga_t* fpga){
	fpga_send(fpga, 0, (void*)instrs, INSTR_SIZE*size, 0, 1, 0);
}

//! Generates an instruction to \b activate the row at the given address.
/*!
  \param \e bank is the bank number.
  \param \e row is the row number.
  \return The generated activate instruction
*/
Instruction genACT(uint bank, uint row){
	Instruction instr = (uint)INSTR_TYPE::DDR;
	instr <<= 32 - CMD_OFFSET - BANK_OFFSET - ROW_OFFSET;
	instr |= 0x23; //sets CKE(1) CS(0) RAS(0) CAS(1) WE_ACT(1)
	instr <<= BANK_OFFSET;
	instr |= bank;
	instr <<= ROW_OFFSET;
	instr |= row;
		
	return instr;
}

//! Generates an instruction to \b precharge the given bank.
/*!
  \param \e bank is the bank number.
  \param \e pc is the precharge type with default value PRE_TYPE.SINGLE.
Can be \e PRE_TYPE.SINGLE for a single-bank precharge, or \e PRE_TYPE.ALL 
for an all-banks precharge).
  \return The generated precharge instruction
*/
Instruction genPRE(uint bank, PRE_TYPE pc){
	Instruction instr = (uint)INSTR_TYPE::DDR;
	instr <<= 32 - CMD_OFFSET - BANK_OFFSET - ROW_OFFSET;
	instr |= 0x22; //to set CKE(1) CS(0) RAS(0) CAS(1) WE_PRE(0)
	if(pc == PRE_TYPE::ALL){
		instr <<= BANK_OFFSET + ROW_OFFSET - COL_OFFSET;
		instr |= 0x1;
		instr <<= COL_OFFSET;
	}
	else{
		instr <<= BANK_OFFSET;
		instr |= bank;
		instr <<= ROW_OFFSET;
	}

	return instr;
}

//! Generates an instruction to \b write a single byte pattern to the given bank/column address.
/*!
  \param \e col is the column number.
  \param \e bank is the bank number.
  \param \e pattern is the byte that will be written to the entire column.
  \param \e ap is the auto-precharge option with default value AUTO_PRECHARGE.NO_AP. 
 Can be \e AUTO_PRECHARGE.AP to perform precharge right after the write,
 or \e AUTO_PRECHARGE.NO_AP for to disable auto-precharge).
  \param \e bl is the burst length with default value BURST_LENGTH.FIXED. 
 Can be \e BURST_LENGTH.FIXED to set burst length to 8, or BURST_LENGTH.CHOP
 to set 4. Do not forget to set MR0 appropriately to enable
 setting the burst length on-the-fly
  \return The generated write instruction
*/
Instruction genWR(uint bank, uint col, uint8_t pattern, AUTO_PRECHARGE ap, BURST_LENGTH bl){
	Instruction instr = (uint)INSTR_TYPE::DDR;
	instr <<= 32 - SIGNAL_OFFSET - BANK_OFFSET - ROW_OFFSET - CMD_OFFSET;

	instr |= pattern >> 2; //most significant 6 bits of the pattern
	instr <<= SIGNAL_OFFSET;

	instr |= 0x24; //to set CKE(1) CS(0)[assumed it should be Low] 
	 	     //RAS(1) CAS(0) WE(0)
	instr <<= BANK_OFFSET;

	instr |= bank;
	instr <<= 2;

	instr |= pattern & 0x3; //least significant 2 bits of the pattern

	instr <<= 2;

	if(bl == BURST_LENGTH::FIXED)
		instr |= 0x1; // to set cmd[12] to 1 (burst length 8)

	instr <<= 2;

	if(ap == AUTO_PRECHARGE::AP)
		instr |= 0x1; // to set cmd[10] to 1

	instr <<= COL_OFFSET;
	instr |= col;

	return instr;
}


//! Generates an instruction to \b read from the given bank/column address.
/*!
  \param \e col is the column number.
  \param \e bank is the bank number.
  \param \e ap is the auto-precharge option with default value AUTO_PRECHARGE.NO_AP. 
 Can be \e AUTO_PRECHARGE.AP to perform precharge right after the read,
 or \e AUTO_PRECHARGE.NO_AP for to disable auto-precharge).
   \param \e bl is the burst length with default value BURST_LENGTH.FIXED.
 Can be \e BURST_LENGTH.FIXED to set burst length to 8, or BURST_LENGTH.CHOP
 to set burst length to 4. Do not forget to set MR0 appropriately to enable
 setting the burst length on-the-fly. 
  \return The generated read instruction
*/
Instruction genRD(uint bank, uint col, AUTO_PRECHARGE ap, BURST_LENGTH bl){
	Instruction instr = 0x25; //to set CKE(1) CS(0)[assumed it should be Low] RAS(1) CAS(0) WE(1)
	
	instr <<= BANK_OFFSET;
	instr |= bank;

	instr <<= 4;

	if(bl == BURST_LENGTH::FIXED)
		instr |= 0x1; // to set cmd[12] to 1 (burst length 8)

	instr <<= 2;

	if(ap == AUTO_PRECHARGE::AP)
		instr |= 0x1; // to set cmd[10] to 1

	instr <<= COL_OFFSET;
	instr |= col;

	Instruction instr2 = (uint)INSTR_TYPE::DDR;
	instr2 <<= 28;

	instr2 |= instr;

	return instr2;
}

//! Generates a \b wait instruction to pause issuing commands for the given
//cycle count.
/*!
  \param \e cycles is the column number.
  \return The generated wait instruction
*/
Instruction genWAIT(uint cycles){ //min 1, max 1023
	assert(cycles >= 1);
	assert(cycles <= 1023 && "Could not wait for more than 1023 cycles since the current hardware implementation has a 10 bit counter for this purpose.");
    	
	Instruction instr = (uint)INSTR_TYPE::WAIT;
	instr <<= 28;
	instr |= cycles;

	return instr;
}

//! Generates an instruction to <b> change bus </b> which switches DQ
//pins between read or write modes.
/*!
  \param \e dir is the new bus mode to be set. Can be BUSDIR.READ to switch to read
mode, or BUSDIR.WRITE to switch to write mode.
  \return The generated change bus direction instruction
*/
Instruction genBUSDIR(BUSDIR dir){
	Instruction instr = (uint)INSTR_TYPE::SET_BUS_DIR;
	instr <<= 28;
	instr |= (uint)dir;

	return instr;
}

//! Generates an instruction to indicate the <b> end of the instruction sequence </b>.
/*!
  \return Instruction used to indicate the end of the instruction sequence
*/
Instruction genEND(){
	return (Instruction)((uint)INSTR_TYPE::END_OF_INSTRS << 28);
}

//! Generates an instruction to initiate DDR3 \b short-ZQ calibration.
/*!
  \return The generated short-ZQ instruction
*/
Instruction genZQ(){
	Instruction instr = (uint)INSTR_TYPE::DDR;
	instr <<= 32 - CMD_OFFSET - BANK_OFFSET - ROW_OFFSET;
	instr |= 0x26; //to set CKE(1) CS(0) RAS(1) CAS(1) WE(0)
	instr <<= BANK_OFFSET + ROW_OFFSET;

	return instr;
}

//! Generates a DDR3 \b refresh instruction.
/*!
  \return The generated refresh instruction
*/
Instruction genREF(){
    Instruction instr = (uint)INSTR_TYPE::DDR;
    instr <<= 32 - CMD_OFFSET - BANK_OFFSET - ROW_OFFSET;

    instr |= 0x21; //to set CKE(1) CS(0) RAS(0) CAS(0) WE(1)

    instr <<= BANK_OFFSET + ROW_OFFSET;

    return instr;
}

//! Generates an instruction for configuring the auto-refresh mechanism.
/*!
  \param \e val is the value to be set.
  \param \e r is the parameter to be configured. Can be \e
MC_CMD.SET_TREFI or MC_CMD.SET_TRFC. See DDR3 datasheet for the definition
of tREFI and tRFC. Set tREFI to 0 to disable auto-refresh (disabled
by default).  
  \return The generated command for auto-refresh configuration
*/
Instruction genREF_CONFIG(uint val, REGISTER r){
    assert(val < 0x10000000);

    Instruction instr = (uint) r;
    instr <<= 28;
    instr |= val;

    return instr;
}
