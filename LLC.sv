//vsim work.TraceHandler "+filename=tracefile.txt" "+mode=normal"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// LLC.sv - Last level cache														      //
//																	      //
// Author:		Hemanth Kumar Bolade (bolade@pdx.edu), Samhitha Kankanala (samhitha@pdx.edu), Kiran Kamble (kamble@pdx.edu)           //
// Last modified:	06-Dec-2022                                                                                                           //
//																	      //
// Description: 8-way set associative L2 Cache (Last level cache) with Pseudo LRU replacement policy and MESI Coherency protocol. 	      //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

`include "defines.sv";

module LLC (
input logic [CMDSIZE-1:0] command,
input logic [ADDR_BITS-1:0] address,
input bit mode,
input bit eof,
output integer reads,
output integer writes,
output real cache_hits,
output real cache_misses
);

logic [ADDR_BITS-1:0] trace_addr;
logic [TAG_BITS-1:0] tag;
logic [SET_BITS-1:0] index;
logic [BYTE_OFFSET_BITS-1:0] byteselect;
logic PLRU[SETS-1:0][PLRU_BITS-1:0];
logic [TAG_BITS-1:0] TAG[SETS-1:0][WAYS-1:0] ;
state_t MESI_STATE[SETS-1:0][WAYS-1:0];
snp_rslt_t SnoopResult;

integer which_way;

assign tag = address[(BYTE_OFFSET_BITS+SET_BITS) +: TAG_BITS];
assign index = address[BYTE_OFFSET_BITS +: SET_BITS];
assign byteselect = address[BYTE_OFFSET_BITS-1 : 0];

initial
begin
	clear_cache;
	reads = 0;
	writes = 0;
	cache_hits = 0;
	cache_misses = 0;
end

always_ff @(posedge eof)
begin
	//if (mode == 0)
	//	$display("\n//Trace_CMD: %0d, Trace_ADDR: %h", command,address);
	case (command)
		0:	read_request_from_L1_data_or_instruction_cache(address);
		1:	write_request_from_L1_data_cache(address);
		2:	read_request_from_L1_data_or_instruction_cache(address);
		3:	snooped_invalidate_request(address);
		4:	snooped_read_request(address);
		5:	snooped_write_request(address);
		6:	snooped_read_with_intent_to_modify_request(address);
		8:	clear_cache;
		9:	print_contents_and_state_of_each_valid_cache_line;
	  default: ;
	endcase
end

//******************************* BUS OPERAION ******************************//
task BusOperation(bus_op_t bus_op, logic [ADDR_BITS-1:0] addr);
begin
	GetSnoopResult(addr);
	if (mode == 0)
	begin
		$display("BusOperation: %s, Address: %h, SnoopResult: %s",bus_op, addr, SnoopResult);
	end
end
endtask : BusOperation

//***************************** GET SNOOP RESULTS ***************************//
task GetSnoopResult (logic [ADDR_BITS-1:0] addr);
begin
	bit [1:0] snoopbits;
	assign snoopbits = addr[1:0];
	case (snoopbits)
		2'b00: SnoopResult = HIT;
		2'b01: SnoopResult = HITM;
		default:SnoopResult = NOHIT;
	endcase
end
endtask : GetSnoopResult

//******************************* PUT SNOOP RESULTS ******************************//
task PutSnoopResult(logic [ADDR_BITS-1:0] addr, snp_rslt_t snoop_result);
begin
	if (mode == 0)
begin
	$display ("PutSnoopResult : Address = %h, snoop_result = %s", addr, snoop_result);
	end
end
endtask : PutSnoopResult

//************************** MESSAGE from L2 to L2 CACHE *************************//
task MessageToCache(msg_to_cache_t msgL2L1, logic [ADDR_BITS-1:0] addr);
begin
	if (mode == 0)
	begin
		$display("L2 to L1 message: %s, Address: %h",msgL2L1,addr);
	end
end
endtask : MessageToCache

//******************************* SEARCH CACHE ******************************//
function int search_cache;
begin
	for (int way_cnt = 0; way_cnt<WAYS; way_cnt++)
	begin
		if ((MESI_STATE[index][way_cnt] != I) && (TAG[index][way_cnt] == tag))
		begin
			search_cache = way_cnt;
			break;
		end
		search_cache = 8;
	end
end
endfunction : search_cache

//******************************* CHECK INVALID ******************************//
function int check_invalid;
begin
	for (int way_cnt = 0; way_cnt<WAYS; way_cnt++)
	begin
		if (MESI_STATE[index][way_cnt] == I)
		begin
			check_invalid = way_cnt;
			break;
		end
	check_invalid = 8;
	end
end
endfunction : check_invalid

//******************************* READ TASK ******************************//
task read_request_from_L1_data_or_instruction_cache(logic [ADDR_BITS-1:0] addr);
begin
	reads++;
	which_way = search_cache;
	if (which_way != 8)
	begin
		cache_hits++;
		MessageToCache(SENDLINE,addr);
		UpdatePLRU(index,which_way);
	end
	else if (which_way == 8)
	begin
		cache_misses++;
		which_way = check_invalid;
		if (which_way != 8)
		begin
			BusOperation(READ,addr);
			TAG[index][which_way] = tag;
			MessageToCache(SENDLINE,addr) ;
			UpdatePLRU(index,which_way);
		end
		else if (which_way == 8)
		begin
			which_way = GetPLRU(index);
			trace_addr = {TAG[index][which_way],index}<<BYTE_OFFSET_BITS;
			if (MESI_STATE[index][which_way] == M)
			begin
				MessageToCache(GETLINE,trace_addr) ;
				BusOperation(WRITE,trace_addr) ;
				MessageToCache(EVICTLINE,trace_addr) ;
				BusOperation(READ,addr) ;
				TAG[index][which_way] = tag;
				UpdatePLRU(index,which_way);
			end
			else if (MESI_STATE[index][which_way] == S || MESI_STATE[index][which_way] == E)
			begin
				MessageToCache(EVICTLINE,trace_addr) ;
				BusOperation(READ,addr) ;
				TAG[index][which_way] = tag;
				MessageToCache(SENDLINE,addr) ;
				UpdatePLRU(index,which_way);
			end
		end
		GetSnoopResult(addr);
		unique case (SnoopResult)
			HIT  : MESI_STATE[index][which_way] = S;
			HITM : MESI_STATE[index][which_way] = S;
			NOHIT: MESI_STATE[index][which_way] = E;
		endcase
	end
end
endtask : read_request_from_L1_data_or_instruction_cache

//******************************* WRITE TASK ******************************//
task write_request_from_L1_data_cache(logic [ADDR_BITS-1:0] addr);
begin
	writes++;
	which_way = search_cache;
	if (which_way != 8)
	begin
		cache_hits++;
		MessageToCache(SENDLINE,addr);
		//MessageToCache(GETLINE,addr);
		UpdatePLRU(index,which_way);
		if (MESI_STATE[index][which_way] == S)
			BusOperation(INVALIDATE,addr);
	end
	else if (which_way == 8)
	begin
		cache_misses++;
		which_way = check_invalid;
		if (which_way != 8)
		begin
			BusOperation(RWIM,addr);
			TAG[index][which_way] = tag;
			MessageToCache(SENDLINE,addr);
			//MessageToCache(GETLINE,addr);
			UpdatePLRU (index,which_way);
		end
		else if (which_way == 8)
		begin
			which_way = GetPLRU(index);
			trace_addr = {TAG[index][which_way],index}<<BYTE_OFFSET_BITS;
			if (MESI_STATE[index][which_way] == M)
			begin
				MessageToCache(GETLINE,trace_addr);
				BusOperation(WRITE,trace_addr);
				MessageToCache(EVICTLINE,trace_addr);
				BusOperation(RWIM,addr);
				TAG[index][which_way] = tag;
				MessageToCache(SENDLINE,addr);
				//MessageToCache(GETLINE,addr);
				UpdatePLRU(index,which_way);
			end
			else if ((MESI_STATE[index][which_way] == S) || (MESI_STATE[index][which_way] == E))
			begin
				MessageToCache(EVICTLINE,trace_addr);
				BusOperation(RWIM,addr);
				TAG[index][which_way] = tag;
				MessageToCache(SENDLINE,addr);
				//MessageToCache(GETLINE,addr);
				UpdatePLRU(index,which_way);
			end
		end
	end
	MESI_STATE[index][which_way] = M;
end
endtask : write_request_from_L1_data_cache

//******************************* SNOOP INVALIDATE TASK ******************************//
task snooped_invalidate_request(logic [ADDR_BITS-1:0] addr);
begin
	which_way = search_cache;
	if ((which_way != 8) && (MESI_STATE[index][which_way] == S))
	begin
		MESI_STATE[index][which_way] = I ;
		PutSnoopResult(addr, HIT);
		MessageToCache(INVALIDATELINE,addr);
	end
	else if (which_way == 8)
	begin
		PutSnoopResult(addr, NOHIT);
	end
end
endtask : snooped_invalidate_request

//******************************* SNOOP READ TASK ******************************//
task snooped_read_request(logic [ADDR_BITS-1:0] addr);
begin
	which_way = search_cache;
	if (which_way != 8)
	begin
		if (MESI_STATE[index][which_way] == M)
		begin
			PutSnoopResult(addr, HITM);
			MessageToCache(GETLINE,addr);
			BusOperation(WRITE,addr);
			MESI_STATE[index][which_way] = S;
		end
		else if (MESI_STATE[index][which_way] == E)
		begin
			PutSnoopResult(addr, HIT);
			MESI_STATE[index][which_way] = S;
		end
		else if (MESI_STATE[index][which_way] == S)
		begin
			PutSnoopResult(addr, HIT);
		end
	end
	else if (which_way == 8)
	begin
		PutSnoopResult(addr, NOHIT);
	end
end
endtask : snooped_read_request

//******************************* SNOOP WRITE TASK ******************************//
task snooped_write_request (logic [ADDR_BITS-1:0] addr);
begin
	// Nothing to be DONE
end
endtask

//******************************* SNOOP RWIM - Read with intent to modify TASK ******************************//
task snooped_read_with_intent_to_modify_request(logic [ADDR_BITS-1:0] addr);
begin
	which_way = search_cache;
	if (which_way != 8)
	begin
		if (MESI_STATE[index][which_way] == M)
		begin
			PutSnoopResult(addr,HITM);
			MessageToCache(GETLINE,addr);
			BusOperation(WRITE,addr);
			MESI_STATE[index][which_way] = I;
			MessageToCache(INVALIDATELINE,addr);			
		end
		else if (MESI_STATE[index][which_way] == E || MESI_STATE[index][which_way] == S)
		begin
			PutSnoopResult(addr,HIT);
			MESI_STATE[index][which_way] = I;
			MessageToCache(INVALIDATELINE,addr);
			end
	end
	else if (which_way == 8) 
	begin	
		PutSnoopResult(addr,NOHIT);
	end
end
endtask : snooped_read_with_intent_to_modify_request

//******************************* TASK TO CLEAR THE CACHE ******************************//
task clear_cache;
begin
	for(int index_cnt = 0; index_cnt < SETS; index_cnt++) 
	begin
		for(int way_cnt = 0; way_cnt < WAYS; way_cnt++) 
		begin
			MESI_STATE[index_cnt][way_cnt] = I;
		end
	end	
end
endtask : clear_cache

//******************************* TASK TO PRINT CONTENTS & STATES OF EACH VALID CACHE LINE ******************************//	
task print_contents_and_state_of_each_valid_cache_line;
begin
int index,way;
	$display ("//--------- CMD 9, ALL VALIDS SUMMARY-----------//");
	for (index = 0;index<SETS; index++)
	begin
		for (way = 0;way<WAYS; way++)
		begin
			if (MESI_STATE[index][way] != I ) 
			begin
				logic [SET_BITS-1:0] pindex ;
				pindex = index;
				$display ("way = %0d, Tag= %h,index = %h, addr = %h,State = %s",way,TAG[index][way],pindex,{TAG[index][way],pindex,6'b0},MESI_STATE[index][way]);
			end
		end
	end		
	$display ("//----------------------------------------------//");

end
endtask : print_contents_and_state_of_each_valid_cache_line
	
//---------------------------------------------//
//		       PLRU                    //
//---------------------------------------------//
//******************************* TASK TO UPDATE PLRU BITS ******************************//
task UpdatePLRU (int nindex, int nway);
	case (nway)
		0:	begin
				PLRU[nindex][0] = 0;
				PLRU[nindex][1] = 0;
				PLRU[nindex][3] = 0;
			end
		1:	begin
				PLRU[nindex][0] = 0;
				PLRU[nindex][1] = 0;
				PLRU[nindex][3] = 1;
			end
		2:	begin
				PLRU[nindex][0] = 0;
				PLRU[nindex][1] = 1;
				PLRU[nindex][4] = 0;
			end
		3:	begin
				PLRU[nindex][0] = 0;
				PLRU[nindex][1] = 1;
				PLRU[nindex][4] = 1;
			end
		4:	begin
				PLRU[nindex][0] = 1;
				PLRU[nindex][2] = 0;
				PLRU[nindex][5] = 0;
			end
		5:	begin
				PLRU[nindex][0] = 1;
				PLRU[nindex][2] = 0;
				PLRU[nindex][5] = 1;
			end
		6:	begin
				PLRU[nindex][0] = 1;
				PLRU[nindex][2] = 1;
				PLRU[nindex][6] = 0;
			end
		7:	begin
				PLRU[nindex][0] = 1;
				PLRU[nindex][2] = 1;
				PLRU[nindex][6] = 1;
			end
	endcase
endtask : UpdatePLRU

//******************************* TASK TO GET PLRU BITS ******************************//
function logic[PLRU_BITS-1:0] GetPLRU (int nindex);
logic [PLRU_BITS-1:0] getlru;
begin
	if(PLRU[nindex][0] == 1'b0)
	begin
		if(PLRU[nindex][2] == 1'b0)
		begin
			if(PLRU[nindex][6] == 1'b0)
				getlru = 'd7;
			else
				getlru = 'd6;
		end
		else 
		begin
			if(PLRU[nindex][5] == 1'b0)
				getlru = 'd5;
			else
				getlru = 'd4;
		end
	end
	else
	begin
		if(PLRU[nindex][1] == 1'b0)
		begin
			if(PLRU[nindex][4] == 1'b0)
				getlru = 'd3;
			else
				getlru = 'd2;
		end
		else 
		begin
			if(PLRU[nindex][3] == 1'b0)
				getlru = 'd1;
			else
				getlru = 'd0;
		end		
	end
	GetPLRU = getlru;
end
endfunction : GetPLRU

//-------------------------------------------------------------------------------------------------------------------------------//
endmodule : LLC
//-------------------------------------------------------------------------------------------------------------------------------//
