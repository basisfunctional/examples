%% An example of how to generate a complex QPSK waveform
%%
%% Summary
%%
%% Random bits are converted into symbols
%% The symbols are zero stuffed to increase the sampling rate
%% A raised cosine filter is then applied
%% The samples are saved as a Midas Blue file (type 1000)
%% A 'Renni' Software Defined Radio made by Basis is used to playback the samples
%%
%% http://www.basisfunctional.com
%%
clear all; clc;

% settings
desired_samples = 65536;
upsample_ratio = 8;
fs = 4e6;
cf = 2420e6;
alpha = 0.5;
format = 'CI';
file_name = 'qpsk_wave_ci.tmp';
cp_len = 16;

% generate a random symbols
rbits = randi([0, 1], 1, 2*desired_samples);
% perform a QPSK modulation (scale by 800)
rsymbols = 800*(2*(complex(rbits(1:2:end)-0.5, rbits(2:2:end)-0.5)));
% create zero-order hold buffer
zoh_symbols = zeros(1, upsample_ratio*(desired_samples+cp_len));
% create the cyclic prefix
cp = rsymbols(end-cp_len+1:end);
% stuff in cp and symbols
zoh_symbols(1:upsample_ratio:end) = [cp, rsymbols];

% generate a raised cosine filter
rcos = GenerateRaisedCosine(upsample_ratio, alpha);

% calculate filter delay
filter_delay = round((length(rcos)-1)/2);
% filter zero order hold symbols (apply pad so we can remove filter delay)
filtered_symbols = filter(rcos, 1, [zoh_symbols, zeros(1, filter_delay)]);
% calculate # of samples to remove from front/back to create phase continuity
half_cp_len_upsampled = upsample_ratio * cp_len / 2;
% remove filter delay and front cp
filtered_symbols(1:filter_delay+half_cp_len_upsampled) = [];
% remove back cp
filtered_symbols(end-half_cp_len_upsampled+1:end) = [];

% write to file
WriteBlueFile(file_name, filtered_symbols.', fs, format, cf);

% build frequency array
num_samples = length(filtered_symbols);
freqs_ = fs * (((0:num_samples-1)/num_samples)-0.5);

%  plot data
figure(1);clf;
%
subplot(2, 1, 1)
hold on; grid on;
plot(real(filtered_symbols), 'r')
plot(imag(filtered_symbols), 'k')
legend('real', 'imag')
title('Time Domain')
xlabel('Num Samples')
ylabel('Amplitude (counts)')
%
subplot(2, 1, 2)
hold on; grid on;
plot(freqs_, 20*log10(abs(fftshift(fft(filtered_symbols)/num_samples))), 'k')
title('Frequency Domain')
xlabel('Frequency (Hz)')
ylabel('Amplitude (dBc)')
