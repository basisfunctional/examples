%% Write Blue File (Currently only complex type 1000)
%%
%% Blue File Documentation:
%% https://nextmidas.techma.com/nm/nxm/sys/docs/MidasBlueFileFormat.pdf
%%
%% Inputs
%%
%% filepath - Path to Blue File (output)
%% data - Array of complex data samples
%% fs - Desired sampling rate (in Hz)
%% format - Output data format, currently supported types: CB|CI|CL|CX|CF|CD
%% cf - Desired center frequency (in Hz, optional. Only used as metadata)
%%
%% Outputs
%%
%% None
%%
function WriteBlueFile(filepath, data, fs, format, cf)

% check number of arguments
if (nargin < 4)
  disp(['Error, cannot write Blue file. Not enough input arguments. Expecting at least 4 got ', num2str(nargin)])
  return;
end

% check format
if format == 'CB'
  bps = 2;
  dtype = 'int8';
elseif format == 'CI'
  bps = 4;
  dtype = 'int16';
elseif format == 'CL'
  bps = 8;
  dtype = 'int32';
elseif format == 'CX'
  bps = 16;
  dtype = 'int64';
elseif format == 'CF'
  bps = 8;
  dtype = 'single';
elseif format == 'CD'
  bps = 16;
  dtype = 'double';
else
  disp(['Error, unsupported type (', format, '). Currently supported types: CB|CI|CL|CX|CF|CD'])
  return
end

% determine the number of samples
num_samples = length(data);
if (num_samples < 1)
  disp('Error, cannot create Blue file with no data')
  return;
elseif ~iscomplex(data)
  disp('Error, currently only complex data is supported')
  return
end

% open file
fd = fopen(filepath, 'w');
% check that file descriptor is open
if (fd < 0)
  disp(['Error, could not open ', file_name, ' for writing'])
  return
end

% create header
hdr = uint8(zeros(1, 512));
% write endianess
hdr(1:12) = cast('BLUEEEEIEEEI', 'uint8');
% write data start
hdr(33:40) = typecast(double(512), 'uint8');
% write number of bytes
hdr(41:48) = typecast(double(num_samples*bps), 'uint8');
% write type 1000
hdr(49:52) = typecast(int32(1000), 'uint8');
% write format
hdr(53:54) = cast(format, 'uint8');
% write sampling rate
hdr(265:272) = typecast(double(1/fs), 'uint8');
% write xunits
hdr(273:276) = typecast(int32(1), 'uint8');
% check for CF
if (nargin > 4)
  % write our special CF keyword
  hdr(165:168) = cast('CFHZ', 'uint8');
  % write value
  hdr(169:176) = typecast(double(cf), 'uint8');  
end
% write header
rv = fwrite(fd, hdr, 'uint8');

% step by 512 samples
step = 512;
% create our interleaved buffer
idata = zeros(1, 2*step);
% write data
nwrote = 0;
for off=1:step:num_samples
  % check remaining
  available = num_samples - (off-1);
  if (available >= step)
    % plenty of data
    end_off = off+step-1;
  else
    % less than a full buffer, alter end so that we don't overstep
    end_off = num_samples;
    % thin data buffer so we don't write too much data to file
    idata(2*available+1:end) = [];
  end
  % interleave the data
  idata(1:2:end) = real(data(off:end_off));
  idata(2:2:end) = imag(data(off:end_off));
  % convert data to data type
  cdata = cast(idata, dtype);
  % write to file
  cur_wrote = fwrite(fd, cdata, dtype);
end

% close the file
fclose(fd);
