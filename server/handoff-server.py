#!/usr/bin/env python
#
# Simple HTTPS Server with Authentication
# By Chris Blake (chrisrblake93@gmail.com)
#

import base64, os, socket, sys
from SocketServer import BaseServer
from BaseHTTPServer import HTTPServer
from SimpleHTTPServer import SimpleHTTPRequestHandler
from OpenSSL import SSL

key = ""

class SecureHTTPServer(HTTPServer):
	def __init__(self, server_address, HandlerClass):
		BaseServer.__init__(self, server_address, HandlerClass)
		ctx = SSL.Context(SSL.SSLv23_METHOD)
		#server.pem's location (containing the server private key and
		#the server certificate).
		fpem = './py-server.pem'
		ctx.use_privatekey_file (fpem)
		ctx.use_certificate_file(fpem)
		self.socket = SSL.Connection(ctx, socket.socket(self.address_family, self.socket_type))
		self.server_bind()
		self.server_activate()

	def shutdown_request(self,request):
		request.shutdown()

class SecureAuthHandler(SimpleHTTPRequestHandler):
	def setup(self):
		self.connection = self.request
		self.rfile = socket._fileobject(self.request, "rb", self.rbufsize)
		self.wfile = socket._fileobject(self.request, "wb", self.wbufsize)

	def do_HEAD(self):
		self.send_response(200)
		self.send_header('Content-type', 'text/html')
		self.end_headers()

	def do_AUTHHEAD(self):
		self.send_response(401)
		self.send_header('WWW-Authenticate', 'Basic realm=\"Authorized Access Only!\"')
		self.send_header('Content-type', 'text/html')
		self.end_headers()

	def do_GET(self):
		global key
		if self.headers.getheader('Authorization') == None:
			self.do_AUTHHEAD()
			self.wfile.write('no auth header received')
			pass
		elif self.headers.getheader('Authorization') == 'Basic '+key:
			SimpleHTTPRequestHandler.do_GET(self)
			# Once we get the file, terminate the server
			path = self.path
			if 'client.ovpn' in path:
				print 'Client Config was downloaded!'
				self.server.socket.close() # dirty, but works! :D
			else:
				pass
		else:
			self.do_AUTHHEAD()
			self.wfile.write(self.headers.getheader('Authorization'))
			self.wfile.write('not authenticated')
			pass

def test(port):
	try:
		server_address = ('', port)
		httpd = SecureHTTPServer(server_address, SecureAuthHandler)
		sa = httpd.socket.getsockname()
		print "Serving HTTPS on", sa[0], "port", sa[1], "..."
		httpd.serve_forever()

	except (KeyboardInterrupt, SystemExit):
		httpd.socket.close()

if __name__ == '__main__':
	if len(sys.argv)<3:
		print "usage handoff-server.py [port] [username:password]"
		sys.exit()
	key = base64.b64encode(sys.argv[2])
	test(int(sys.argv[1]))
