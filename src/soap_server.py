import SOAPpy
from xmlapi import *
import repmgr
import re

server_url = "http://node6501.gplhost.com/dtc-xen/soap"
server_port = "8080"

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


soapserver = SOAPpy.SOAPServer((server_url, server_port))
soapserver.registerFunction(testVPSServer)
soapserver.registerFunction(startVPS)
soapserver.registerFunction(destroyVPS)
soapserver.registerFunction(shutdownVPS)
soapserver.registerFunction(listStartedVPS)
soapserver.serve_forever()
