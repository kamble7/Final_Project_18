//--------------------------------------------------------------------------------------------------------------------------------
// DEFINES
//--------------------------------------------------------------------------------------------------------------------------------

`define CACHE_CAP 	16*(2**20)*8  	                                                 			// 16MB of cache, expressed in bits
`define LINE_CAP 	64*8					                                                          	// 64B line capacity in cache
`define WAYS		8						                                                                	// 8 Way Associativity in cache
`define ADDR_BITS	32							                                                           // Address bits of cache
`define CPU_DATA_BUS	8					                                                          	// CPU is a byte addressable
`define MESI_STATE_BITS	2				                                                       		// MESI protocol bits

parameter CACHE_CAP			=	`CACHE_CAP;  		                                               // 16MB of cache, expressed in bits
parameter LINE_CAP			=	`LINE_CAP;			                                                  // 64B line capacity in cache
parameter WAYS				=	`WAYS;				                                                        // 8 Way Associativity in cache
parameter ADDR_BITS			=	`ADDR_BITS;			                                                // Address bits of cache
parameter CPU_DATA_BUS		=	`CPU_DATA_BUS;		                                            // CPU is a byte addressable
parameter MESI_STATE_BITS	=	`MESI_STATE_BITS;		                                       // MESI protocol bits

parameter BYTE_OFFSET_BITS 	=	$clog2((LINE_CAP)/CPU_DATA_BUS);                        // Byte Offset bits
parameter WAY_BITS			=	$clog2(WAYS);                                                  // bits required for 8-way set associative
parameter SETS				= 	CACHE_CAP/(WAYS*LINE_CAP);                                       // Number of sets
parameter SET_BITS			=	$clog2(SETS);                                                  // Number of Bits required for the given sets
parameter TAG_BITS			=	ADDR_BITS - SET_BITS - BYTE_OFFSET_BITS;                       // Tag Bits
parameter PLRU_BITS			=	WAYS-1;                                                       // PLRU Bits

parameter CMDSIZE  = 4;                                                               // Command Size requires 4 bits as we have n = 9

typedef enum bit[1:0] {M,E,S,I}state_t;                                               // MESI
typedef enum bit[1:0] {NOHIT, HIT, HITM}snp_rslt_t;                                   // Snoop Results
typedef enum bit[2:0] {READ=3'b1, WRITE, INVALIDATE, RWIM}bus_op_t;                   // Bus Operation
typedef enum bit[2:0] {GETLINE,SENDLINE,INVALIDATELINE,EVICTLINE} msg_to_cache_t;     // L2 to L1 message types
