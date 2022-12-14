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


initial
begin
if ($value$plusargs ("filename=%s", filename))
	//$display ("Input File_name : %s",filename);

if ($value$plusargs ("mode=%s", mode))
begin
	//$display ("Operating Mode : %s",mode);
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
if (!fd_r)
begin
	$display ("File %s is NOT opened successfully", filename);
	$stop;
end
	
while (!$feof(fd_r))
begin
	eof = 0;
	trace = $fscanf (fd_r,"%d %h",command,address);
	if (trace > 0)
	begin
		eof = 1;
		if((cache_hits+cache_misses)!=0)
		#10	cache_hit_ratio = (cache_hits/(cache_hits+cache_misses));
		else
		#10 cache_hit_ratio = 0;  
	end
end
eof = 0;
if((cache_hits+cache_misses)!=0)
begin
$display ("\n//----------------------------------STATISTICS--------------------------------------//");
$display ("//reads: %0d, writes: %0d, cache_hits: %0d, cache_misses: %0d, cache_hit_ratio: %.2f//",reads,writes,cache_hits,cache_misses,cache_hit_ratio);
$display ("//----------------------------------------------------------------------------------//");
end
else 
begin
	$display ("\n//----------------------------------STATISTICS--------------------------------------//");
	$display ("//reads: %0d, writes: %0d, cache_hits: %0d, cache_misses: %0d, no cache hit ratio",reads,writes,cache_hits,cache_misses);
	$display ("//----------------------------------------------------------------------------------//");
end
$fclose (fd_r);	//closing file
end

//--------------------------------------------------------------------------------------------------------------------------------
endmodule : TraceHandler
//--------------------------------------------------------------------------------------------------------------------------------
