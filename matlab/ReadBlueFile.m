%% Read Blue File (Currently only type 1000)
%%
%% Blue File Documentation:
%% https://nextmidas.techma.com/nm/nxm/sys/docs/MidasBlueFileFormat.pdf
%%
%% Inputs
%%
%% filepath - Path to Blue File
%% numSamples - Desired number of data samples (Optional)
%% offset - Desired sample offset (Optional)
%%
%% Outputs
%%
%% hdr - Midas Header Structure Containing Metadata about data samples
%% output - Output Samples
%%
function [hdr, output] = ReadBlueFile(filepath, num_samples, offset)

% initiliaze outputs
hdr = struct();
output = [];

% determine 
if (nargin < 1)
  disp('Error, cannot read Blue file. No file path provided')
  return;
elseif (nargin < 2)
  numSamples = -1;
end
if (nargin < 3)
  offset = 0;
end

% open file
fd = fopen(filepath);
if fd < 0
  disp(['Error, could not open {', filepath, '} for reading'])
  return
end

% read the header 
raw_hdr = fread(fd, 512, 'uint8');
if (length(raw_hdr) != 512)
  disp(['Error, Blue file {', filepath, '} does not have a valid header'])
  return
elseif (typecast(uint8(raw_hdr(49:52)), 'int32') != 1000)
  disp('Error, currently only type 1000 files  are supported');
  return;
end

% get sampling rate
xdel = typecast(uint8(raw_hdr(265:272)), 'double');
if (xdel > 0)
  fs = 1.0 / xdel;
else 
  fs = 0;
  disp('Warning, invalid sampling rate');
end

% look for our special 'CFHZ' keyword
if (strcmp(char(raw_hdr(165:168))', 'CFHZ'))
  % get center frequency
  cf = typecast(uint8(raw_hdr(169:176)), 'double');
else
  cf = 0;
end

% perform read
switch (char(raw_hdr(54)))
  case {'B', 'b'}
    data_type = 'int8';
    bytes_per_element = 1;
  case {'I', 'i'}
    data_type = 'int16';
    bytes_per_element = 2;
  case {'L', 'l'}
    data_type = 'int32';
    bytes_per_element = 4;
  case {'F', 'f'}
    data_type = 'single';
    bytes_per_element = 4;
  otherwise
    disp(['Error, cannot read unhandled data type (', char(raw_hdr(54)), ')'])
    return
endswitch

% determine if data is complex
isComplex = raw_hdr(53) == 67;

% determine sizes
num_bytes = typecast(uint8(raw_hdr(41:48)), 'double');

% calculate available samples
available_samples = num_bytes / bytes_per_element;
% calculate desired elements
desired_elements = num_samples;
% check if data is complex
if (isComplex)
  % appropriately alter available and desired
  available_samples = available_samples / 2;
  desired_elements = desired_elements * 2;
end

% calculate seek
if (offset > 0)
  if isComplex
    seek_pos = bytes_per_element * offset * 2;
  else
    seek_pos = bytes_per_element * offset;
  end
  % perform seek
  fseek(fd, seek_pos, 'cof');
end

% perform read
output = fread(fd, desired_elements, data_type);

% close the file
fclose(fd);

% determine if data is complex
if (isComplex)
  % convert to complex
  output = complex(output(1:2:end), output(2:2:end));
end

% build header structure
hdr = struct('available_samples', {available_samples}, 'cf', {cf}, 'fs', {fs});
