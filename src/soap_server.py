import sys
from SOAPpy import *
from M2Crypto import SSL

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

def auth(userid, password, mode='clear', auth=None):
  return userid

if not Config.SSLserver:
  raise RuntimeError, "this Python installation doesn't have OpenSSL and M2Crypto"

ssl_context = SSL.Context()
ssl_context.load_cert('privkey.pem')

soapserver = SOAPpy.SOAPServer((server_url, server_port))
soapserver.registerFunction(auth)
soapserver.registerFunction(testVPSServer)
soapserver.registerFunction(startVPS)
soapserver.registerFunction(destroyVPS)
soapserver.registerFunction(shutdownVPS)
soapserver.registerFunction(listStartedVPS)
print "Starting dtc-xen python SOAP server at http://%s:%s/ ..." % (server_url, server_port)
try:
  soapserver.serve_forever()
except KeyboardInterrupt:
  pass
