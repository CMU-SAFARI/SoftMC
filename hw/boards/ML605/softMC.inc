//uncomment the line below to run a simulation using "tb_softMC_top"
//`define SIM

`define tCK 2500

// instruction opcodes
`define DDR_INSTR 4'b1xxx
`define END_ISEQ 4'b0000
`define SET_BUSDIR 4'b0001
`define SET_TREFI 4'b0010
`define SET_TRFC 4'b0011
`define WAIT 4'b0100



`define ROW_OFFSET 16
`define WE_OFFSET 19
`define CAS_OFFSET 20
`define RAS_OFFSET 21
`define CS_OFFSET 22
`define CKE_OFFSET 24



`define BUS_DIR_READ 2'b00
`define BUS_DIR_WRITE 2'b10

//Set accordingly to tCK, (6, 6, 14 if tCK = 2500ps)
`define DEF_TRP 15000/`tCK
`define DEF_TRCD 15000/`tCK
`define DEF_TRAS 35000/`tCK
`define DEF_TZQCS 64 //mem_clk cycles
