#!/usr/bin/env python

import sys
import math
import struct
import numpy as np
import matplotlib.pyplot as plt
import socket
from scipy.fftpack import fft
from scipy.signal import hanning
import BasisPacket

mcast_group = "224.0.0.1"
mcast_port = 9093

if len(sys.argv) > 1:
    mcast_group = sys.argv[1]
if len(sys.argv) > 2:
    mcast_port = int(sys.argv[2])

# create packet object
packet = BasisPacket.BasisPacket()
# get packet size
packetSize = packet.packetSize()

try:
    # try to connect
    print("Attempting to connect to %s:%d" % (mcast_group, mcast_port))
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(('', mcast_port))
    # connect to group
    group = socket.inet_aton(mcast_group)
    mreq = struct.pack('4sL', group, socket.INADDR_ANY)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
    # try to get some data
    (raw,address) = sock.recvfrom(packetSize)
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

sock.close()

