//--------------------------------------------------------------------------------------------------------------------------------
// DEFINES
//--------------------------------------------------------------------------------------------------------------------------------

//`define DEBUG		0
`define CACHE_CAP 	16*(2**20)*8  				// 16MB of cache, expressed in bits
`define LINE_CAP 	64*8						// 64B line capacity in cache
`define WAYS		8							// 8 Way Associativity in cache
`define ADDR_BITS	32							// Address bits of cache
`define CPU_DATA_BUS	8						// CPU is a byte addressable
`define MESI_STATE_BITS	2						// MESI protocol bits
//`define TRUE		1
//`define FALSE		0



//parameter debug_switch = `DEBUG;

parameter CACHE_CAP			=	`CACHE_CAP;  		// 16MB of cache, expressed in bits
parameter LINE_CAP			=	`LINE_CAP;			// 64B line capacity in cache
parameter WAYS				=	`WAYS;				// 8 Way Associativity in cache
parameter ADDR_BITS			=	`ADDR_BITS;			// Address bits of cache
parameter CPU_DATA_BUS		=	`CPU_DATA_BUS;		// CPU is a byte addressable
parameter MESI_STATE_BITS	=	`MESI_STATE_BITS;		// MESI protocol bits

parameter BYTE_OFFSET_BITS 	=	$clog2((LINE_CAP)/CPU_DATA_BUS);
parameter WAY_BITS			=	$clog2(WAYS);
parameter SETS				= 	CACHE_CAP/(WAYS*LINE_CAP);
parameter SET_BITS			=	$clog2(SETS);
parameter TAG_BITS			=	ADDR_BITS - SET_BITS - BYTE_OFFSET_BITS;
parameter PLRU_BITS			=	WAYS-1;

parameter CMDSIZE  = 4;
//parameter ADDRSIZE = 32;

//typedef enum bit[3:0] {CPU_READ_DATA,CPU_WRITE_DATA,CPU_READ_INSTRUCTION,SNOOP_INVALIDATE,SNOOP_READ,SNOOP_WRITE,SNOOP_RWIM,CLEAR,PRINT,CPU_NO_OP}cmd_t;
typedef enum bit[3:0] {CPU_READ,CPU_WRITE,SNOOP_INVALIDATE,SNOOP_READ,SNOOP_WRITE,SNOOP_RWIM,CPU_NO_OP,CLEAR,PRINT}cmd_t;
typedef enum bit[1:0] {M,E,S,I}state_t;

typedef enum bit[1:0] {NOHIT, HIT, HITM}snp_rslt_t;
typedef enum bit[2:0] {READ=3'b1, WRITE, INVALIDATE, RWIM}bus_op_t;
typedef enum bit[2:0] {GETLINE,SENDLINE,INVALIDATELINE,EVICTLINE} msg_to_cache_t;

/*
// Bus Operation types
 
`define READ    1  // Bus Read 
`define WRITE   2  // Bus Write 
`define INVALIDATE  3  // Bus Invalidate
`define RWIM    4  // Bus Read With Intent to Modify
 
 
// Snoop Result types
 
`define NOHIT   0  // No hit 
`define HIT    1  // Hit
`define HITM   2  // Hit to modified line
 
// L2 to L1 message types
 
`define GETLINE     1  // Request data for modified line in L1
`define SENDLINE    2  // Send requested cache line to L1
`define INVALIDATELINE  3  // Invalidate a line in L1
`define EVICTLINE    4  // Evict a line from L1
*/