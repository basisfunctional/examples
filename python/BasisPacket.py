import struct
import numpy as np

# Dictionary of Data Format Enums and the associated number of bytes per sample
DataFormats = {
    0x00:  1, #  ScalarUint8
    0x01:  1, #  ScalarInt8
    0x02:  2, #  ScalarUInt16
    0x03:  2, #  ScalarInt16
    0x04:  4, #  ScalarUInt32
    0x05:  4, #  ScalarInt32
    0x06:  8, #  ScalarUInt64
    0x07:  8, #  ScalarInt64
    0x08: 16, #  ScalarUInt128
    0x09: 16, #  ScalarInt128
    0x0a:  2, #  ScalarFloat16
    0x0b:  4, #  ScalarFloat32
    0x0c:  8, #  ScalarFloat64
    0x0d: 16, #  ScalarFloat128
    0x80:  2, #  ComplexUint8
    0x81:  2, #  ComplexInt8
    0x82:  4, #  ComplexUInt16
    0x83:  4, #  ComplexInt16
    0x84:  8, #  ComplexUInt32
    0x85:  8, #  ComplexInt32
    0x86: 16, #  ComplexUInt64
    0x87: 16, #  ComplexInt64
    0x88: 32, #  ComplexUInt128
    0x89: 32, #  ComplexInt128
    0x8a:  4, #  ComplexFloat16
    0x8b:  8, #  ComplexFloat32
    0x8c: 16, #  ComplexFloat64
    0x8d: 32, #  ComplexFloat128
    0xff:  0  # invalid
}

class BasisPacket(object):

    def __init__(self):
        self.valid = False
        self.dataFormat = 0
        self.fs = 0
        self.cf = 0
        self.pktNum = 0

    def packetSize(self):
        # sizes; header: 64, payload: 960
        return 1024

    def isComplex(self):
        return self.dataFormat & 0xF0 == 0x80

    def bytesPerSample(self):
        return DataFormats.get(self.dataFormat, 0xff)

    def numSamples(self):
        bytesPer = self.bytesPerSample()
        return self.numBytes // bytesPer

    def isValid(self):
        if self.fs <= 0:
            print("Error, invalid sampling rate (%f)" % self.fs)
            return False
        elif self.bytesPerSample() == 0:
            print("Error, invalid data format (%d)" % self.dataFormat)
            return False
        return True

    def unpack(self, raw):
        packetSize = self.packetSize()
        if len(raw) != packetSize:
            print("Invalid packet size %d, expecting (%d)" % (len(raw), packetSize))
            return False
        # unpack meta
        (self.dataFormat, self.numBytes, self.fs, self.cf, self.packetNum) = struct.unpack('<BIddH', raw[0:23])
        print("Format: 0x%x, data bytes: %u, fs: %f, cf: %f, pkt # %u" %
                (self.dataFormat, self.numBytes, self.fs, self.cf, self.packetNum))

        # check if valid
        if self.isValid() == False:
            print("Packet is invalid")
            return False

        # unpack (currently only supports 'short' format)
        if self.__unpackData(self.dataFormat, raw[64:1024]) == False:
            print("Could not unpack data")
            return False

        return True

    def __unpackData(self, dataFormat, buf):
        print("Unpacking data, format: 0x%x" % dataFormat)

        # unpack data
        numSamples = self.numSamples()
        if self.isComplex():
            self.data = np.zeros(numSamples, dtype=complex)
            for m, n in zip(range(numSamples), range(0, len(buf), 4)):
                self.data[m] = complex(struct.unpack('<h', buf[n  :n+2])[0],
                                       struct.unpack('<h', buf[n+2:n+4])[0])
        else:
            self.data = np.zeros(numSamples)
            for m, n in zip(range(numSamples), range(0, len(buf), 2)):
                self.data[m] = struct.unpack('<h', buf[n:n+2])[0]

        return True

