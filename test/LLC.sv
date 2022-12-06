//vsim work.TraceHandler "+filename=tracefile.txt" "+mode=normal"
//--------------------------------------------------------------------------------------------------------------------------------
//LLC
//--------------------------------------------------------------------------------------------------------------------------------
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
logic PLRU[SETS-1:0][WAYS-1:0];
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
assign trace_addr = address[BYTE_OFFSET_BITS+: (SET_BITS+TAG_BITS)] << BYTE_OFFSET_BITS ;

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
		end
		else if (which_way == 8)
		begin
			which_way = GetPLRU(index);
			if (MESI_STATE[index][which_way] == M)
			begin
				MessageToCache(GETLINE,addr) ;
				BusOperation(WRITE,addr) ;
				MessageToCache(EVICTLINE,addr) ;
				BusOperation(READ,addr) ;
				TAG[index][which_way] = tag;
				UpdatePLRU(index,which_way);
			end
			else if (MESI_STATE[index][which_way] == S || MESI_STATE[index][which_way] == E)
			begin
				MessageToCache(EVICTLINE,addr) ;
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

//---------------------------------------------
//PLRU
//---------------------------------------------
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


function GetPLRU (int nindex);
logic [PLRU_BITS-1:0] getlru;
begin
	if(PLRU[nindex][0] == 0)
	begin
		if(PLRU[nindex][2] == 0)
		begin
			if(PLRU[nindex][6] == 0)
				getlru = 'd7;
			else
				getlru = 'd6;
		end
		else 
		begin
			if(PLRU[nindex][5] == 0)
				getlru = 'd5;
			else
				getlru = 'd4;
		end
	end
	else
	begin
		if(PLRU[nindex][1] == 0)
		begin
			if(PLRU[nindex][4] == 0)
				getlru = 'd3;
			else
				getlru = 'd2;
		end
		else 
		begin
			if(PLRU[nindex][3] == 0)
				getlru = 'd1;
			else
				getlru = 'd0;
		end		
	end
	return getlru;
end
endfunction : GetPLRU


//---------------------------------------------
endmodule : LLC
//--------------------------------------------------------------------------------------------------------------------------------
