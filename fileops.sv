// change by sam
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

if (mode==="S")
	$display ("Operating Mode ===s : %s",mode);
if (mode==="SILENT")
	$display ("Operating Mode ===SILENT : %s",mode);
	
	
fd_r = $fopen (filename,"r");
if (fd_r)
	$display ("File %s is opened successfully", filename);
else
	$display ("File %s is NOT opened successfully", filename);
	
while (!$feof(fd_r))
begin
	$fscanf (fd_r,"%s",command);
	$fscanf (fd_r,"%h",address);
	//$fgets (fd_r,"%s",content);
	$display ("command: %d, address: %h",command,address);
end
$fclose (fd_r);	//closing file
end
endmodule : fileops