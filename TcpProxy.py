#!/usr/bin/env false

import socket
import select
import errno
from collections import defaultdict

class TcpProxy(object):
    def __init__(self, server_host, server_port, proxy_host, proxy_port, handler=None):
        self.server_host = server_host
        self.server_port = int(server_port)

        self.proxy_host = proxy_host
        self.proxy_port = int(proxy_port)

        self.handler = handler

        self.buffer_size = 2048

        self.connections_map = {}
        self.serverbound = defaultdict(lambda: False)

    def run(self):
        print ("Starting TCP proxy on {}:{}".format(self.proxy_host, self.proxy_port))

        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.setblocking(0)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.bind( (self.proxy_host, self.proxy_port) )
            sock.listen(5)

            self.connections_map[sock] = sock

            while True:
                readable, _, _ = select.select(self.connections_map.values(), [], [])

                for s in readable:
                    if (s == sock):
                        # New connection
                        client, addr = sock.accept()
                        print ("Accepted connection {} {}".format(addr[0], addr[1]))

                        rserver = self.connect()

                        if (rserver):
                            # All OK, set nonblocking mode and remember correspondence
                            rserver.setblocking(0)
                            client.setblocking(0)
                            self.connections_map[client] = rserver
                            self.connections_map[rserver] = client
                            self.serverbound[client] = True
                        else:
                            print ("Can't establish connection to server, closing connection")
                            client.close()
                    else:
                        # Data from existing connection
                        data = self.receive(s)
                        if (len(data) > 0):
                            # Process data
                            if (self.handler):
                                self.handler(self.serverbound[s], data) # TODO
                            # Send data
                            self.send(s, data)
                        else:
                            # Close connection
                            self.cleanup(s)
        except KeyboardInterrupt:
            print ("Stopping server")
        except Exception as e:
            print ("Something went wrong: {}".format(e))

        for s in self.connections_map.values():
            s.shutdown(1)
            s.close()

    def connect(self):
        try:
            print ("Creating new connection to {} {}".format(self.server_host, self.server_port))
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect( (self.server_host, self.server_port) )
            return sock
        except Exception as e:
            print ("Connection to remote server failed: {}".format(e))
            return None

    def send(self, sock, data):
        pair_sock = self.connections_map[sock]
        pair_sock.send(data)

    def receive(self, sock):
        buff = bytes()
        try:
            cont = True
            while cont:
                data = sock.recv(self.buffer_size)
                if (not data):
                    cont = False
                else:
                    buff += data
        except socket.error as e:
            err = e.args[0]
            if err == errno.EAGAIN or err == errno.EWOULDBLOCK:
                # As we are in non-blocking mode, that error means that there's no more data
                #print ("No data available")
                pass
            else:
                print ("Read error: {}".format(e))
        except Exception as e:
            print ("Read error: {}".format(e))

        return buff

    def cleanup(self, sock):
        print ("Cleaning up connection")
        pair_sock = self.connections_map[sock]
        self.connections_map[sock].close()
        self.connections_map[pair_sock].close()
        del self.connections_map[sock]
        del self.connections_map[pair_sock]
