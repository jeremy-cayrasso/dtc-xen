#!/usr/bin/env python
import sys
import os
import SOAPpy
from SOAPpy import *

# debug
SOAPpy.Config.debug=1

from M2Crypto import SSL

import crypt
sys.path.append( '/usr/lib/dtc-xen' )
from Properties import *

# import xm stuff
sys.path.append( '/usr/lib/python' ) #Required to import from /usr/lib/python for FC4
import xen.xm.main as xenxm

# print crypt.crypt('somepw','py')


# read config file
p=Properties()
p.load(open('/etc/dtc-xen/soap.conf'))
server_host=p.getProperty("soap_server_host");
server_port=int(p.getProperty("soap_server_port"));
cert_passphrase=p.getProperty("soap_server_pass_phrase");

# server_host = "mirror.tusker.net"
# server_host = "dtc.xen650202.gplhost.com"
# server_port = 8089

def testVPSServer():
  return "ok"

def startVPS(vpsname):
	xmargs=['foo', 'create', vpsname]
	print "Starting %s..." % vpsname
	xenxm.main(xmargs)
	return "OK","Started %s" % vpsname

def destroyVPS(vpsname):
	xmargs=['foo','destroy',vpsname]
	print "Destroying %s..." % vpsname
	xenxm.main(xmargs)
	return "OK","Destroyed %s" % vpsname

def shutdownVPS(vpsname):
	xmargs=['foo','shutdown',vpsname]
	print "Shutting down %s..." % vpsname
	xenxm.main(xmargs)
	return "OK","Shutdown %s" % vpsname

def infoVPS(vpsname):
	infos=['vpsname']
	return "OK",infos

def listStartedVPS():
	doms = xenxm.server.xend_domains()
	doms.sort()
	return doms

def getVPSState(vpsname):
	info = xenxm.server.xend_domain(vpsname)
	return info
#	d = {}
#	d['dom'] = int(xenxm.sxp.child_value(info, 'id', '-1'))
#	d['name'] = xenxm.sxp.child_value(info, 'name', '??')
#	d['mem'] = int(xenxm.sxp.child_value(info, 'memory', '0'))
#	d['cpu'] = int(xenxm.sxp.child_value(info, 'cpu', '0'))
#	d['state'] = xenxm.sxp.child_value(info, 'state', '??')
#	d['cpu_time'] = float(sxp.child_value(info, 'cpu_time', '0'))
#	return d

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

  # get authorization info from HTTP headers
  ah = c.httpheaders.get("Authorization","")

  if ah:
    # decode and analyze the string for the username and password
    # (we slice the string from 6 onwards to remove the "Basic ")
    username, password = base64.decodestring(ah[6:].strip()).split(":")
    print "Authorization string: \"%s\"" % (ah,)
    print "Username: \"%s\" Password: \"%s\"" % (username, password)

    print "Loading /etc/dtc-xen/htpasswd..."
    fd = open('/etc/dtc-xen/htpasswd', 'r') 

    for line in fd:
      u, h = line.strip().split(':')
      if u == username:
        print "Found user: ",username
	print "Password from file: ", h
        verify_pass = crypt.crypt(password, h[:2])
        print "Check hash password: ",verify_pass
	if verify_pass == h:
          print "Password matches the one in the file!"
          return 1
        else:
          print "Password didn't match the one in .htpasswd"
          return 0
    
    print "Couldn't find user in password file!"
    return 0
    
  else:
    print "NO authorization information in HTTP headers, refusing."
    return 0

def auth(userid, password, mode='clear', auth=None):
  print "auth called..."
  return userid

def _passphrase(cert):
  print "Pass phrase faked..."
  return cert_passphrase

if not Config.SSLserver:
  raise RuntimeError, "this Python installation doesn't have OpenSSL and M2Crypto"

ssl_context = SSL.Context()
ssl_context.load_cert('/etc/dtc-xen/dtc-xen.cert.cert', '/etc/dtc-xen/privkey.pem', callback=_passphrase)

soapserver = SOAPpy.SOAPServer((server_host, server_port), ssl_context = ssl_context)
# No ssl 
# soapserver = SOAPpy.SOAPServer((server_host, server_port))
soapserver.registerFunction(auth)
soapserver.registerFunction(_authorize)
soapserver.registerFunction(testVPSServer)
soapserver.registerFunction(startVPS)
soapserver.registerFunction(destroyVPS)
soapserver.registerFunction(shutdownVPS)
soapserver.registerFunction(listStartedVPS)
soapserver.registerFunction(getVPSState)
print "Starting dtc-xen python SOAP server at https://%s:%s/ ..." % (server_host, server_port)
while True:
	try:
	  soapserver.serve_forever()
	except KeyboardInterrupt:
          print "Shutting down..."
	  sys.exit(0)
	except:
	  print "Caught exception handling connection"
