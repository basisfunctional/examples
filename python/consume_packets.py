#!/usr/bin/env python

import sys
import math
import numpy as np
import matplotlib.pyplot as plt
import socket
from scipy.fftpack import fft
from scipy.signal import hanning
import Packet

url = "renni.local"
port = 9091

packet = Packet.Packet()
packetSize = packet.packetSize()

if len(sys.argv) > 1:
    url =  sys.argv[1]

# try to connect
print("Attempting to connect to %s" % url)
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((url, port))

try:
    # try to get some data
    raw = s.recv(packetSize)
    print("Received %d bytes" % len(raw))
    # de-packetize
    if packet.unpack(raw) == False:
        print("Could not de-packetize data")
        exit()
    numSamples = packet.numSamples()
    # fft (with normalization)
    yf = np.fft.fftshift(fft(packet.data * hanning(numSamples)) / numSamples)
    # setting up our plots
    # build fd axis
    xf = np.linspace(-0.5*packet.fs+packet.cf, 0.5*packet.fs+packet.cf, numSamples)
    # build td axis
    xt = np.linspace(0, numSamples/packet.fs, numSamples)
    # get the max time domain point
    maxVal = 1.2*math.ceil(max(max(abs(packet.data.real)), max(abs(packet.data.imag))))
    # plot
    if packet.isComplex:
        plt.figure(1)
        # time domain
        plt.subplot(211)
        plt.plot(xt, packet.data.real, 'r', label='real')
        plt.plot(xt, packet.data.imag, 'k', label='imag')
        legend = plt.legend(loc='upper right', shadow=True)
        plt.title('Time Domain')
        plt.axis([0, xt[-1], -maxVal, maxVal])
        plt.grid()
        # frequency domain
        plt.subplot(212)
        plt.semilogy(xf, np.abs(yf))
        plt.title('Frequency Domain')
        plt.xlim([xf[0], xf[-1]])
        plt.grid()
        plt.show()
except KeyboardInterrupt:
    pass

s.close()

