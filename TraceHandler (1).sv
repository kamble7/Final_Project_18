//--------------------------------------------------------------------------------------------------------------------------------
// Trace file handling
//--------------------------------------------------------------------------------------------------------------------------------

`include "defines.sv";

module TraceHandler ();
logic [CMDSIZE-1:0] command;
logic [ADDR_BITS-1:0] address;
integer reads,writes,cache_hits,cache_misses;

string filename, mode;

integer fd_r;
integer trace;

LLC llc_inst(.command(command),
				.address(address),
				.reads(reads),
				.writes(writes),
				.cache_hits(cache_hits),
				.cache_misses(cache_misses));


initial
begin
if ($value$plusargs ("filename=%s", filename))
	$display ("Input File_name : %s",filename);

if ($value$plusargs ("mode=%s", mode))
	$display ("Operating Mode : %s",mode);
	
	
fd_r = $fopen (filename,"r");
if (fd_r)
	$display ("File %s is opened successfully", filename);
else
	$display ("File %s is NOT opened successfully", filename);
	
while (!$feof(fd_r))
begin
	#10 trace = $fscanf (fd_r,"%d",command);
	if (command < 8) 
	begin
		trace = $fscanf (fd_r,"%h",address);
		$display ("\n\ncommand: %d, address: %h",command,address);
		//#10	$display (" tag_hit : %d, tag_miss: %d, hit_way: %d, invalid_way: %d,\ntag is %b, Index is %b , byteselect is %b",llc_inst.tag_hit,llc_inst.tag_miss,llc_inst.hit_way,llc_inst.invalid_way,llc_inst.tag, llc_inst.index , llc_inst.byteselect);
		//#10	$display (" which_way : %d, \ntag is %b, Index is %b , byteselect is %b",llc_inst.which_way,llc_inst.tag, llc_inst.index , llc_inst.byteselect);
			#10	$display ("reads: %d, writes: %d, cache_hits: %d, cache_misses: %d",reads,writes,cache_hits,cache_misses);
	end
	else 
	begin
		//command = 'dz;
		address = 'dz;
	end
	#10;
end
$fclose (fd_r);	//closing file
end

endmodule : TraceHandler

//--------------------------------------------------------------------------------------------------------------------------------
