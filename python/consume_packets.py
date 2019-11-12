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
packet_size = packet.packetSize()

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
    (raw,address) = sock.recvfrom(packet_size)
    print("Received %d bytes" % len(raw))
    # de-packetize
    if packet.unpack(raw) == False:
        print("Could not de-packetize data")
        exit()
    # get the number of samples
    num_samples = packet.numSamples()
    # get the IQ data
    iq_samples = packet.data
    # fft (apply a Hanning window)
    yf = np.fft.fftshift(fft(iq_samples * hanning(num_samples)) / num_samples)
    # setting up our plots
    # build frequency domain axis
    xf = 1e-6*np.linspace(-0.5*packet.fs, 0.5*packet.fs, num_samples)
    # build time domain axis
    xt = np.linspace(0, num_samples/packet.fs, num_samples)
    # get the max time domain point (so we can do setup an axis range)
    max_range = 1.2*math.ceil(max(max(abs(packet.data.real)), max(abs(packet.data.imag))))
    # plot (note: data is currently always complex)
    if packet.isComplex:
        plt.figure(1)
        plt.suptitle('Renni Capture')
        # time domain
        plt.subplot(211)
        plt.plot(xt, packet.data.real, 'r', label='real')
        plt.plot(xt, packet.data.imag, 'k', label='imag')
        legend = plt.legend(loc='upper right', shadow=True)
        plt.title('Time Domain')
        plt.xlabel('Time (secs)')
        plt.ylabel('Amplitude (ADC counts)')
        plt.axis([0, xt[-1], -max_range, max_range])
        plt.grid()
        # frequency domain
        plt.subplot(212)
        plt.plot(xf, 20*np.log10(np.abs(yf)))
        plt.title('Frequency Domain (Center Frequency: ' + str(packet.cf*1e-6) + ' MHz)')
        plt.xlabel('Frequency (MHz)')
        plt.ylabel('Power (dBc)')
        plt.xlim([xf[0], xf[-1]])
        plt.grid()
        plt.show()
except KeyboardInterrupt:
    pass

sock.close()

