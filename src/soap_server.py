#!/usr/bin/env python
import sys
import SOAPpy
from SOAPpy import *
from M2Crypto import SSL

# debug
SOAPpy.Config.debug=1

# server_url = "mirror.tusker.net"
server_url = "dtc.xen650202.gplhost.com"
server_port = 8089

def testVPSServer():
  return "ok"

def startVPS(vpsname):
  return "ok"

def destroyVPS(vpsname):
  return "ok"


def shutdownVPS(vpsname):
  return "ok"

def listStartedVPS():
  return "ok"

# ask for returned SOAP responses to be converted to basic python types
Config.simplify_objects = 1

# specify name of authorization function
Config.authMethod = "_authorize"

def _authorize(*args, **kw):
  global Config
  print "_authorize called..."
  c = kw["_SOAPContext"]
  print "**kw =%s" % str(kw)

  # The socket object, useful for
  print "Peer connected: ",  c.connection.getpeername()

  print "basicAuthEchoServer.echoClass._authorize"
 
  # get authorization info from HTTP headers
  ah = c.httpheaders.get("Authorization","")

  if ah:
    # decode and analyze the string for the username and password
    # (we slice the string from 6 onwards to remove the "Basic ")
    username, password = base64.decodestring(ah[6:].strip()).split(":")
    print "Authorization string: \"%s\"" % (ah,)
    print "Username: \"%s\" Password: \"%s\"" % (username, password)
    
    # do username,password checks here and decide on action
    if username == "JohnDoe" and password == "JDsPassword":
      print "Allowing request"
      return 1
    
    else:
      print "Refusing request"
      return 0
    
  else:
    print "NO authorization information in HTTP headers, refusing."
    return 0

  return 1

def auth(userid, password, mode='clear', auth=None):
  print "auth called..."
  return userid

def _passphrase(cert):
  print "Pass phrase faked..."
  return "aaaa"

if not Config.SSLserver:
  raise RuntimeError, "this Python installation doesn't have OpenSSL and M2Crypto"

ssl_context = SSL.Context()
ssl_context.load_cert('soap.cert.cert', 'privkey.pem', callback=_passphrase)

soapserver = SOAPpy.SOAPServer((server_url, server_port), ssl_context = ssl_context)
# No ssl 
# soapserver = SOAPpy.SOAPServer((server_url, server_port))
soapserver.registerFunction(auth)
soapserver.registerFunction(_authorize)
soapserver.registerFunction(testVPSServer)
soapserver.registerFunction(startVPS)
soapserver.registerFunction(destroyVPS)
soapserver.registerFunction(shutdownVPS)
soapserver.registerFunction(listStartedVPS)
print "Starting dtc-xen python SOAP server at https://%s:%s/ ..." % (server_url, server_port)
while True:
	try:
	  soapserver.serve_forever()
	except KeyboardInterrupt:
          print "Shutting down..."
	  sys.exit(0)
	except:
	  print "Caught exception handling connection"
