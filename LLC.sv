//vsim work.TraceHandler "+filename=tracefile.txt" "+mode=normal"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// LLC.sv - Last level cache														      //
//																	      //
// Author:		Hemanth Kumar Bolade (bolade@pdx.edu), Samhitha Kamkanala (samhitha@pdx.edu), Kiran Kamble (kamble@pdx.edu)           //
// Last modified:	06-Dec-2022                                                                                                           //
//																	      //
// Description: 8-way set associative L2 Cache (Last level cache) with Pseudo LRU replacement policy and MESI Coherency protocol. 	      //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

`include "defines.sv";

module LLC (
input logic [CMDSIZE-1:0] command,
input logic [ADDR_BITS-1:0] address,
output integer reads,
output integer writes,
output integer cache_hits,
output integer cache_misses
);

logic [ADDR_BITS-1:0] trace_addr;
logic [TAG_BITS-1:0] tag;
logic [SET_BITS-1:0] index;
logic [BYTE_OFFSET_BITS-1:0] byteselect;
logic PLRU[SETS-1:0][PLRU_BITS-1:0];
logic [TAG_BITS-1:0] TAG[SETS-1:0][WAYS-1:0] ;
state_t MESI_STATE[SETS-1:0][WAYS-1:0];
snp_rslt_t SnoopResult;

bit tag_hit;
bit tag_miss;

integer which_way;
integer hit_way;
integer invalid_way;
//integer way_cnt;
//cmd_t cmd;

assign tag = address[(BYTE_OFFSET_BITS+SET_BITS) +: TAG_BITS];
assign index = address[BYTE_OFFSET_BITS +: SET_BITS];
assign byteselect = address[BYTE_OFFSET_BITS-1 : 0];
//assign trace_addr = address[BYTE_OFFSET_BITS+: (SET_BITS+TAG_BITS)] << BYTE_OFFSET_BITS ;

initial
begin
	$display("BYTE_OFFSET_BITS: %d,\n WAY_BITS: %d,\n SETS	: %d,\n SET_BITS: %d,\n TAG_BITS : %d,\n PLRU_BITS	: %d,\n ",BYTE_OFFSET_BITS,WAY_BITS,SETS,SET_BITS,TAG_BITS,PLRU_BITS);
	clear_cache;
	reads = 0;
	writes = 0;
	cache_hits = 0;
	cache_misses = 0;
end

always_comb
begin
	case (command)
		0:	read_request_from_L1_data_cache(address);
		1:	write_request_from_L1_data_cache(address);
		2:	read_request_from_L1_data_cache(address);
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
	$display("BusOperation: %s, Address: %h, SnoopResult: %s",bus_op, addr, SnoopResult);
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
	$display ("PutSnoopResult : Address = %h, snoop_result = %s", addr, snoop_result);
end
endtask : PutSnoopResult

//************************** MESSAGE from L2 to L2 CACHE *************************//
task MessageToCache(msg_to_cache_t msgL2L1, logic [ADDR_BITS-1:0] addr);
begin
	$display("L2 to L1 message: %s, Address: %h",msgL2L1,addr);
end
endtask : MessageToCache

//******************************* SEARCH CACHE ******************************//
function int search_cache;
begin
	for (int way_cnt = 0; way_cnt<WAYS; way_cnt++)
	begin
			/*
			$display ("Input address: %h, %b",address,address);
			$display ("Input tag:%b, search_tag: %b",tag,TAG[index][way_cnt]);
			$display ("Input index:%b, byte:%b",index,byteselect);
			$display ("MESI: %s",MESI_STATE[index][way_cnt]);
			*/
		if ((MESI_STATE[index][way_cnt] != I) && (TAG[index][way_cnt] == tag))
		begin
			//$display ("way_cnt: %d",way_cnt);
			search_cache = way_cnt;
			break;
		end
		//$display ("way_cnt_8: %d",8);
		search_cache = 8;
	end
	//$display ("way_cnt_8: %d",8);
	//search_cache = 8;
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
			//$display ("chk_inv_way_cnt_f: %d",way_cnt);

			break;
		end
		//$display ("chk_inv_way_cnt_f8: %d",8);

	check_invalid = 8;
	end
	//$display ("chk_inv_way_cnt_f8: %d",8);
	//check_invalid = 8;
end
endfunction : check_invalid

//******************************* READ TASK ******************************//
task read_request_from_L1_data_cache(logic [ADDR_BITS-1:0] addr);
begin
	reads++;
	which_way = search_cache;
	//$display("\nread_which_way = %d\n",which_way);
	if (which_way != 8)
	begin
		cache_hits++;
		MessageToCache(SENDLINE,addr);
		UpdatePLRU(index,which_way);
		//$display("\nupdatePLRU_which_way = %p\n",PLRU[index]);

	end
	else if (which_way == 8)
	begin
		cache_misses++;
		which_way = check_invalid;
		//$display("\ninvalid_which_way = %d\n",which_way);
		if (which_way != 8)
		begin
			BusOperation(READ,addr);
			TAG[index][which_way] = tag;
			MessageToCache(SENDLINE,addr) ;
			UpdatePLRU(index,which_way);
			//$display("\nupdatePLRU_which_way = %p\n",PLRU[index]);

		end
		else if (which_way == 8)
		begin
			which_way = GetPLRU(index);
			trace_addr = {TAG[index][which_way],index}<<BYTE_OFFSET_BITS;
			
			$display("addr= %h \ntrace_addr= %h\n",{TAG[index][which_way],index,6'b0},trace_addr);
			if (MESI_STATE[index][which_way] == M)
			begin
				MessageToCache(GETLINE,trace_addr) ;
				BusOperation(WRITE,trace_addr) ;
				MessageToCache(EVICTLINE,trace_addr) ;
				BusOperation(READ,addr) ;
				TAG[index][which_way] = tag;
				UpdatePLRU(index,which_way);
				//$display("\nupdatePLRU_which_way = %p\n",PLRU[index]);

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
endtask : read_request_from_L1_data_cache

//******************************* WRITE TASK ******************************//
task write_request_from_L1_data_cache(logic [ADDR_BITS-1:0] addr);
begin
	writes++;
	which_way = search_cache;
	if (which_way != 8)
	begin
		//if (MESI_STATE[index][hit_way] == M || MESI_STATE[index][hit_way] == E || MESI_STATE[index][hit_way] == S)
		//begin
			cache_hits++;
			MessageToCache(SENDLINE,addr);
			//MessageToCache(GETLINE,addr);
			UpdatePLRU(index,which_way);
			if (MESI_STATE[index][which_way] == S)
				BusOperation(INVALIDATE,addr);
		//end
	end
	else if (which_way == 8)
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
		$display("addr= %h \ntrace_addr= %h\n",{TAG[index][which_way],index,6'b0},trace_addr);
		
		if (MESI_STATE[index][invalid_way] == M)
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
	MESI_STATE[index][which_way] = M;
end
endtask : write_request_from_L1_data_cache

//******************************* SNOOP INVALIDATE TASK ******************************//
task snooped_invalidate_request(logic [ADDR_BITS-1:0] addr);
begin
	which_way = search_cache;
	if ((which_way != 8) && (MESI_STATE[index][which_way] == S))
	begin
		//if (MESI_STATE[index][which_way] == M || MESI_STATE[index][which_way] == E || MESI_STATE[index][which_way] == S)
		//if (MESI_STATE[index][which_way] == S)
		//begin
			MESI_STATE[index][which_way] = I ;
			PutSnoopResult(addr, HIT);
			MessageToCache(INVALIDATELINE,addr);
		//end
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
			//$display ("MESI_STATE = %s", MESI_STATE[index_cnt][way_cnt]);
			//TAG[index_cnt][way_cnt] = 'b0;
		end
	end	
end
endtask : clear_cache

//******************************* TASK TO PRINT CONTENTS & STATES OF EACH VALID CACHE LINE ******************************//	
task print_contents_and_state_of_each_valid_cache_line;
begin
int index,way;
	for (index = 0;index<SETS; index++)
	begin
		for (way = 0;way<WAYS; way++)
		begin
			if (MESI_STATE[index][way] != I ) 
			begin
				logic [SET_BITS-1:0] pindex ;
				pindex = index;
				$display ("way = %0d, Tag= %h,index = %h, pindex=%h, addr = %h,State = %s",way,TAG[index][way],index,pindex,{TAG[index][way],pindex,6'b0},MESI_STATE[index][way]);
			end
		end
	end		
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
	//$display("\nupdatePLRU_which_way = %p\n",PLRU[index]);

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
		$display("\ngetPLRU_func = %d\n",getlru);

	GetPLRU = getlru;
end
endfunction : GetPLRU

//-------------------------------------------------------------------------------------------------------------------------------//
endmodule : LLC
//-------------------------------------------------------------------------------------------------------------------------------//
