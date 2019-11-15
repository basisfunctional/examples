CC=gcc
CFLAGS=-I.
LIBS=

consume_packets: consume_packets.c
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

.PHONY: consume_packets clean

clean:
	rm -f consume_packets

