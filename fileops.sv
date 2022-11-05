// checkpoint 1 code

module fileops ();
string filename,mode,command,s;
integer address;
integer fd_r;

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
	$fscanf (fd_r,"%s",command);
	$fscanf (fd_r,"%h",address);
	$display ("command: %d, address: %h",command,address);
end
$fclose (fd_r);	//closing file
end

endmodule : fileops