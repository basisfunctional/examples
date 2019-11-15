/*
 * consume_packets.c
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <getopt.h>
#include <unistd.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include "BasisPacket.h"

void print_usage (const char* app)
{
  printf("Usage for %s\n", app);
  printf("  -a <ADDRESS>         -  Host name or address of server (i.e. 'localhost', '192.168.0.25', 'renni.home')\n");
  printf("  -d <DESIRED_SAMPLES> -  Number of IQ samples to save to output file\n");
  printf("  -o <OUTPUT PATH>     -  Path to output file\n");
  printf("  -p <PORT>            -  Port of server\n");
  printf("  -h                   -  This help message\n");
  printf("\n");
}

int main (int argc, char* argv[])
{
  /* default arguments */
  const char* group = "224.12.34.56";
  uint32_t port = 9083;
  const char* output_path = "iq_data.bin";
  int32_t desired_samples = 8192;
  int32_t num_samples = 0;
  int opt = 0;
  int fd, num_bytes, rc, sock;
  struct timeval tv;
  mode_t mode_;
  struct BasisPacket packet;
  struct ip_mreq mreq;
  uint32_t pkt_bytes, pkt_samples, write_bytes;
  struct sockaddr_in addr;
  socklen_t address_len = sizeof(addr);
  /* look for user inputs */
  while((opt = getopt(argc, argv, "a:d:o:p:h")) != -1) {
    switch(opt) {
      case 'a':
        group = optarg;
        break;
      case 'd':
        desired_samples = atoi(optarg);
        break;
      case 'o':
        output_path = optarg;
        break;
      case 'p':
        port = atoi(optarg);
        break;
      case 'h':
      default:
        print_usage(argv[0]);
        exit(1);
    }
  }
  /* display relevant variables */
  printf("Attempting to capture %d sample(s) to '%s' from '%s:%d'\n",
      desired_samples, output_path, group, port);
  /* setup output file permissions */
  mode_ = S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH;
  /* open file */
  fd = open(output_path, O_TRUNC|O_WRONLY|O_CREAT, mode_);
  /* check descriptor  */
  if (fd < 0) {
    printf("Error, could not open file '%s' (%s)", output_path, strerror(fd));
    exit(1);
  }
  /* create socket */
  sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (sock < 0) {
    printf("Error, could not create socket (%s)\n", strerror(sock));
    exit(1);
  }
  /* allow address reuse */
  opt = 1;
  rc = setsockopt(sock, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, sizeof(opt));
  if (rc) {
    printf("Error, could not setup address re-use (%s)\n", strerror(rc));
    exit(1);
  }
  /* set timeout structure */
  tv.tv_sec = 1;
  tv.tv_usec = 0;
  /* set receive timeout */
  rc = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof tv);
  if (rc) {
    printf("Error, could not set socket receive timeout duration (%s)\n", strerror(rc));
    exit(1);
  }
  /* setup transmit timeout */
  tv.tv_sec = 2;
  tv.tv_usec = 0;
  rc = setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (const char*)&tv, sizeof tv);
  if (rc) {
    printf("Error, could not set socket transmit timeout duration (%s)\n", strerror(rc));
    exit(1);
  }
  /* populate structure */
  memset(&addr, 0, address_len);
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  addr.sin_port = htons(port);
  /* receive */
  rc = bind(sock, (struct sockaddr *) &addr, address_len);
  if (rc) {
    printf("Error, could not bind socket (%s)\n", strerror(rc));
    exit(1);
  }
  /* setup multicast subscription */
  mreq.imr_multiaddr.s_addr = inet_addr(group);
  mreq.imr_interface.s_addr = htonl(INADDR_ANY);
  /* subscribe to multicast */
  rc = setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, sizeof(mreq));
  if (rc) {
    printf("Error, could not subscribe to multicast (%s)\n", strerror(rc));
    exit(1);
  }
  /* get packet size */
  pkt_bytes = sizeof(packet);
  while (num_samples < desired_samples) {
    /* receive packet */
    num_bytes = recvfrom(sock, &packet, pkt_bytes, 0, (struct sockaddr *) &addr, &address_len);
    /* check size and validity */
    if (num_bytes == pkt_bytes && is_packet_valid(&packet) == 0) {
      /* display some packet information. note: each sample has 4 bytes (complex int16) */
      printf("Received packet has %d samples (CF: %.01f MHz, FS: %.01f MHz)\n",
          packet.dataBytes >> 2, packet.cf*1e-6, packet.fs*1e-6);
      /* calculate remaining bytes */
      write_bytes = (desired_samples - num_samples) << 2;
      /* check write bytes with available */
      if (write_bytes > packet.dataBytes) {
        write_bytes = packet.dataBytes;
      }
      /* write data to file */
      num_bytes = write(fd, packet.raw, write_bytes);
      /* check number of bytes written */
      if (num_bytes == write_bytes) {
        /* increment samples wrote */
        num_samples += num_bytes >> 2;
      }
      else {
        printf("Error, only wrote %d of %u bytes. Exiting\n", num_bytes, write_bytes);
        break;
      }
    }
    else {
      printf("Error, packet is invalid. Exiting\n");
      break;
    }
  }
  printf("Wrote %d samples to to '%s'\n", num_samples, output_path);
  /* close socket */
  close(sock);
  /* close file */
  close(fd);
  printf("Packet consumer ran to completion\n");
  return 0;
}
