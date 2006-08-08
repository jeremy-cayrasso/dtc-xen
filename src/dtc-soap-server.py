#!/usr/bin/env python
import sys
import os
import SOAPpy
import commands
from StringIO import StringIO
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
	  return "OK"

def startVPS(vpsname):
	username = getUser()
	if username == "dtc-xen" or username == vpsname:
		xmargs=['foo', 'create', vpsname]
		print "Starting %s..." % vpsname
		localsysout = StringIO()
		localsyserr = StringIO()
		sys.stdout = localsysout
		sys.stderr = localsyserr
		try:
			xenxm.main(xmargs)
			return "OK","Started %s" % vpsname
		except:
			sys.stdout = sys.__stdout__
			sys.stderr = sys.__stderr__
			returnString =  "NOTOK - %s %s" % (localsyserr.getvalue(), localsysout.getvalue())
			localsyserr.close()
			localsysout.close()
			return returnString
	else:
		return "NOTOK"

def destroyVPS(vpsname):
	username = getUser()
	if username == "dtc-xen" or username == vpsname:
		xmargs=['foo','destroy',vpsname]
		print "Destroying %s..." % vpsname
		localsysout = StringIO()
                localsyserr = StringIO()
                sys.stdout = localsysout
                sys.stderr = localsyserr
		try:
			xenxm.main(xmargs)
			return "OK","Destroyed %s" % vpsname
		except:
			sys.stdout = sys.__stdout__
                        sys.stderr = sys.__stderr__
			returnString =  "NOTOK - %s %s" % (localsyserr.getvalue(), localsysout.getvalue())
			localsyserr.close()
			localsysout.close()
			return returnString
	else:
		return "NOTOK"

def shutdownVPS(vpsname):
	username = getUser()
	if username == "dtc-xen" or username == vpsname:
		xmargs=['foo','shutdown',vpsname]
		print "Shutting down %s..." % vpsname
		localsysout = StringIO()
                localsyserr = StringIO()
                sys.stdout = localsysout
                sys.stderr = localsyserr
		try:
			xenxm.main(xmargs)
			return "OK","Shutdown %s" % vpsname
		except:
                        sys.stdout = sys.__stdout__
                        sys.stderr = sys.__stderr__
                        returnString =  "NOTOK - %s %s" % (localsyserr.getvalue(), localsysout.getvalue())
                        localsyserr.close()
                        localsysout.close()
                        return returnString
	else:
		return "NOTOK"

def infoVPS(vpsname):
	username = getUser()
        if username == "dtc-xen" or username == vpsname:
		infos=['vpsname']
		return "OK",infos
	else:
		return "NOTOK"

def listStartedVPS():
	username = getUser()
	if username == "dtc-xen":
		# first check to see if we have a xend_domain method (for 2.x)
		try:
			func = getattr(xenxm.server, "xend_domains")
			if func:
				doms = xenxm.server.xend_domains()
			else:
				print "Couldn't find xend_domains method"
		except:
			doms = xenxm.server.xend.domains(1)
		doms.sort()
		return doms
	else:
		try:
			func = getattr(xenxm.server, "xend_domain")
			if func:
				dom = xenxm.server.xend_domain(username)
			else:
				print "Couldn't find xend_domain method"
		except:
			dom = xenxm.server.xend.domain(username)
		return dom

def changeVPSxmPassword(vpsname,password):
	username = getUser()
	if username == "dtc-xen":
		commands.getstatusoutput("(echo %s; sleep 1; echo %s;) | passwd %s" % (password,password,vpsname))
		return "OK"
	else:
		return "NOTOK"

def changeVPSsoapPassword(vpsname,password):
	username = getUser()
	if username == "dtc-xen" or username == vpsname:
		commands.getstatusoutput("htpasswd -b /etc/dtc-xen/htpasswd %s %s" % (vpsname,password))
		return "OK"
	else:
		return "NOTOK"

def getVPSState(vpsname):
	username = getUser()
        if username == "dtc-xen" or username == vpsname:
		try:
			func = getattr(xenxm.server, "xend_domain")
			if func:
				info = xenxm.server.xend_domain(vpsname)
			else:
				print "Couldn't find xend_domain method"
		except:
			info = xenxm.server.xend.domain(vpsname)
		return info
	else:
		return "NOTOK"
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

def getUser():
  c = GetSOAPContext()
  # get authorization info from HTTP headers
  ah = c.httpheaders.get("Authorization","")

  if ah:
    # decode and analyze the string for the username and password
    # (we slice the string from 6 onwards to remove the "Basic ")
    username, password = base64.decodestring(ah[6:].strip()).split(":")
    return username
  else:
    return 0

def isUserValid(vpsname):
  username = getUser()    
  if vpsname == username:
    print "Valid user: ", username
    return 1
  else:
    return 0

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
soapserver.registerFunction(_authorize)
soapserver.registerFunction(testVPSServer)
soapserver.registerFunction(startVPS)
soapserver.registerFunction(destroyVPS)
soapserver.registerFunction(shutdownVPS)
soapserver.registerFunction(listStartedVPS)
soapserver.registerFunction(getVPSState)
soapserver.registerFunction(changeVPSxmPassword)
soapserver.registerFunction(changeVPSsoapPassword)
print "Starting dtc-xen python SOAP server at https://%s:%s/ ..." % (server_host, server_port)
while True:
	try:
	  soapserver.serve_forever()
	except KeyboardInterrupt:
          print "Shutting down..."
	  sys.exit(0)
	except Exception, e:
	  print "Caught exception handling connection: ", e
