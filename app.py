#!/usr/bin/env python3

import sys

from TcpProxy import TcpProxy
from MinecraftParser import MinecraftParserMulti

class Application(object):
    server_host = "127.0.0.1"
    server_port = 25565

    proxy_host = "127.0.0.1"
    proxy_port = 2021

    def __init__(self):
        if (len(sys.argv) > 2):
            try:
                # Try to parse host and port from the command line
                self.server_host, self.server_port = sys.argv[1].split(':')[0:2]
                self.proxy_host, self.proxy_port = sys.argv[2].split(':')[0:2]
            except Exception as e:
                print ("Can't parse command line: {}".format(e))

        self.proxy = TcpProxy(self.server_host, self.server_port, self.proxy_host, self.proxy_port, MinecraftParserMulti)

    def run(self):
        self.proxy.run()

if (__name__ == '__main__'):
    app = Application()
    app.run()
