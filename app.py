#!/usr/bin/env python3

import sys

from TcpProxy import TcpProxy

class Application(object):
    server_host = "127.0.0.1"
    server_port = 2020

    proxy_host = "127.0.0.1"
    proxy_port = 2021

    dump_filename = "dump.mcproto"

    def __init__(self):
        if (len(sys.argv) > 2):
            try:
                # Try to parse host and port from the command line
                self.server_host, self.server_port = sys.argv[1].split(':')[0:2]
                self.proxy_host, self.proxy_port = sys.argv[2].split(':')[0:2]
            except Exception as e:
                print ("Can't parse command line: {}".format(e))

        self.proxy = TcpProxy(self.server_host, self.server_port, self.proxy_host, self.proxy_port, self.mc_packet)

    def run(self):
        self.file = open(self.dump_filename, "wb")
        self.proxy.run()
        self.file.close()

    def decode_varint(self, data):
        result = 0
        size = 0
        while True:
            i = data[size]
            result |= (i & 0x7f) << (7 * size)
            size += 1
            if not (i & 0x80):
                break

        return (result, size)

    def mc_packet(self, serverbound, data):
        offset = 0
        total_size = len(data)

        while offset < total_size:
            size = sum(self.decode_varint(data[offset:]))
            self.hexdump(serverbound, data[offset:offset+size])
            offset += size

    def hexdump(self, serverbound, data, length=16):
        self.file.write(bytes([serverbound]))
        self.file.write(data)
        filter = ''.join([(len(repr(chr(x))) == 3) and chr(x) or '.' for x in range(256)])
        lines = []
        digits = 4 if isinstance(data, str) else 2
        for c in range(0, len(data), length):
            chars = data[c:c+length]
            hex = ' '.join(["%0*x" % (digits, (x)) for x in chars])
            printable = ''.join(["%s" % (((x) <= 127 and filter[(x)]) or '.') for x in chars])
            lines.append("%04x  %-*s  %s\n" % (c, length*3, hex, printable))
        print('Serverbound: {}'.format(serverbound))
        print(''.join(lines))

if (__name__ == '__main__'):
    app = Application()
    app.run()
