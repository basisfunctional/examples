clear all; clc;

file_path = 'recorded_tone.tmp';
desired_samples = 2000;

[hdr, data] = ReadBlueFile(file_path, desired_samples);

disp(['available samples: ', num2str(hdr.available_samples), ', center frequency: ',  num2str(hdr.cf), ', sampling rate: ', num2str(hdr.fs)])

% determine number of samples read
read_samples = length(data);
% build frequency list
freqs_ = hdr.fs * (((0:read_samples-1)/read_samples) - 0.5);

figure(1); clf;
% time domain plot
subplot(2, 1, 1)
hold on; grid on;
plot(real(data), 'r')
plot(imag(data), 'k')
legend('in-phase', 'quadrature')
title('Time Domain')
xlabel('Samples')
ylabel('Amplitude')
% frequency domain plot
subplot(2, 1, 2)
hold on; grid on;
plot(freqs_, 20*log10(abs(fftshift(fft(data)))))
title('Frequency Domain')
xlabel('Frequency (Hz)')
ylabel('Amplitude')
