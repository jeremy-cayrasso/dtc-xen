import SOAPpy

server_url = "node6501.gplhost.com"
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


soapserver = SOAPpy.SOAPServer(("dtc.xen650202.gplhost.com", server_port))
soapserver.registerFunction(testVPSServer)
soapserver.registerFunction(startVPS)
soapserver.registerFunction(destroyVPS)
soapserver.registerFunction(shutdownVPS)
soapserver.registerFunction(listStartedVPS)
soapserver.serve_forever()
