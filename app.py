#!/usr/bin/env python3

import sys

from inspect import ismethod, isfunction, isclass

from TcpProxy import TcpProxy
from generated.var_int import VarInt
from generated.minecraft_proto import MinecraftProto
from kaitaistruct import KaitaiStream, BytesIO

class Application(object):
    server_host = "127.0.0.1"
    server_port = 2020

    proxy_host = "127.0.0.1"
    proxy_port = 2021

    dump_filename = "dump.mcproto"

    compression_active = False
    game_state = MinecraftProto.GameState.handshake

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

    def get_payload(self, packet):
        payload = None
        if (packet.compressed):
            try:
                payload = packet.payload_c
            except:
                payload = packet.payload_u2
        else:
            payload = packet.payload_u1

        packet_id = payload.packet_id.value

        if (packet.server_bound):
            return (packet_id, payload.data.sb)
        else:
            return (packet_id, payload.data.cb)

    def dump_packet(self, packet):
        packet_id, data = self.get_payload(packet)
        print ("Packet {} (ID 0x{:02x})".format(type(data).__name__, packet_id))

        self.dump(data)

    def dump(self, obj, level = 0):
        padding = 4 * level * ' '
        for a in dir(obj):
            if (not a.startswith('_')):
                val = getattr(obj, a)
                if (ismethod(val) or isfunction(val) or isclass(val)):
                    pass
                elif isinstance(val, (int, float, str, list, dict, set)):
                    print ("{} | {} = {}".format(padding, a, val))
                else:
                    print ("{} {} ({}):".format(padding, a, type(val).__name__))
                    self.dump(val, level + 1)

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

    def switch_state(self, packet):
        if (self.game_state == MinecraftProto.GameState.handshake):
            if (packet.compressed):
                return # Shouldn't happen

            try:
                if (isinstance(packet.payload_u1.data, MinecraftProto.HandshakeData)):
                    next_state = MinecraftProto.GameState(packet.payload_u1.data.sb.next_state.value)
                    print ("Switching state from {} to {}".format(self.game_state, next_state))
                    self.game_state = next_state
            except:
                print ("Not a handshake packet")
        elif (self.game_state == MinecraftProto.GameState.status):
            # TODO
            pass
        elif (self.game_state == MinecraftProto.GameState.login):
            if (not packet.compressed):
                try:
                    if (isinstance(packet.payload_u1.data.cb, MinecraftProto.CbSetCompression)):
                        compression_threshold = packet.payload_u1.data.cb.threshold.value
                        print ("Compression: {}".format(compression_threshold))
                        self.compression_active = compression_threshold > 0
                except:
                    print ("Not a login packet")
            else:
                try:
                    if (isinstance(packet.payload_u2.data.cb, MinecraftProto.CbLoginSuccess)):
                        next_state = MinecraftProto.GameState.play
                        print ("Switching state from {} to {}".format(self.game_state, next_state))
                        self.game_state = next_state
                except:
                    print ("Not a login packet")

    def mc_packet(self, serverbound, data):
        offset = 0
        total_size = len(data)

        while offset < total_size:
            size = sum(self.decode_varint(data[offset:]))

            part = data[offset:offset+size]

            io = KaitaiStream(BytesIO(part))
            packet = MinecraftProto.Packet(self.compression_active, serverbound, self.game_state, io)
            self.dump_packet(packet)

            self.switch_state(packet)

            self.hexdump(serverbound, part)
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
