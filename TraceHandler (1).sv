//--------------------------------------------------------------------------------------------------------------------------------
// Trace file handling
//--------------------------------------------------------------------------------------------------------------------------------
//																	      //
// Author:		Hemanth Kumar Bolade (bolade@pdx.edu), Samhitha Kamkanala (samhitha@pdx.edu), Kiran Kamble (kamble@pdx.edu)           //
// Last modified:	06-Dec-2022                                                                                                           //
//																	      //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

`include "defines.sv";

module TraceHandler ();
logic [CMDSIZE-1:0] command;
logic [ADDR_BITS-1:0] address;
integer reads,writes;
real cache_hits,cache_misses,cache_hit_ratio;
bit eof;

string filename, mode;
bit mode_b;

integer fd_r;
integer trace;

LLC llc_inst(.command(command),
				.address(address),
				.reads(reads),
				.writes(writes),
				.cache_hits(cache_hits),
				.cache_misses(cache_misses),
				.mode(mode_b),
        .eof(eof));

assign cache_hit_ratio = (cache_hits * 100)/(cache_hits+cache_misses);

initial
begin
if ($value$plusargs ("filename=%s", filename))
	$display ("Input File_name : %s",filename);

if ($value$plusargs ("mode=%s", mode))
begin
	$display ("Operating Mode : %s",mode);
	if (mode.tolower == "normal")
		mode_b = 0;
	else if (mode.tolower == "silent")
		mode_b = 1;
	else
	begin
		$display ("**** Invalid mode ****");
		$stop;
	end
end
	
fd_r = $fopen (filename,"r");
if (fd_r)
	$display ("File %s is opened successfully", filename);
else
	$display ("File %s is NOT opened successfully", filename);
	
while (!$feof(fd_r))
begin
	eof = 0;
	#10 trace = $fscanf (fd_r,"%d",command);
	if (command < 8) 
	begin
		trace = $fscanf (fd_r,"%h",address);
		eof = 1;
		$display ("\n\ncommand: %d, address: %h",command,address);
		//#10	$display (" tag_hit : %d, tag_miss: %d, hit_way: %d, invalid_way: %d,\ntag is %b, Index is %b , byteselect is %b",llc_inst.tag_hit,llc_inst.tag_miss,llc_inst.hit_way,llc_inst.invalid_way,llc_inst.tag, llc_inst.index , llc_inst.byteselect);
		//#10	$display (" which_way : %d, \ntag is %b, Index is %b , byteselect is %b",llc_inst.which_way,llc_inst.tag, llc_inst.index , llc_inst.byteselect);
		#10	$display ("reads: %0d, writes: %0d, cache_hits: %0d, cache_misses: %0d, cache_hit_ratio: %.3f%%",reads,writes,cache_hits,cache_misses,cache_hit_ratio);
	end
	else 
	begin
		//command = 'dz;
		address = 'dz;
	end
end
eof = 0;
$fclose (fd_r);	//closing file
end

//--------------------------------------------------------------------------------------------------------------------------------
endmodule : TraceHandler
//--------------------------------------------------------------------------------------------------------------------------------
