#!/usr/bin/env python
import sys, traceback
import os
import SOAPpy
import commands
#import sqlite
from StringIO import StringIO
from SOAPpy import *

# debug
SOAPpy.Config.debug=1

from M2Crypto import SSL

import crypt
sys.path.append( '/usr/share/dtc-xen' )
from Properties import *

# import xm stuff
sys.path.append( '/usr/lib/python' ) #Required to import from /usr/lib/python for FC4
import xen.xm.main as xenxm
try:
	from xen.xend.XendClient import server
except:
	pass

# Checking for Xen version
print "Checking for Xen version"
xen_version = 2
try:
	func = getattr(xenxm.server, "xend_domain")
	if func:
		xen_version = 2
except:
	xen_version = 3

print "Detected Xen vesrion %s" % xen_version

# read config file
p=Properties()
p.load(open('/etc/dtc-xen/soap.conf'))
server_host=p.getProperty("soap_server_host");
server_port=int(p.getProperty("soap_server_port"));
cert_passphrase=p.getProperty("soap_server_pass_phrase");
dtcxen_user=p.getProperty("soap_server_dtcxen_user");
server_lvmname=p.getProperty("soap_server_lvmname");

# server_host = "mirror.tusker.net"
# server_host = "dtc.xen650202.gplhost.com"
# server_port = 8089

def testVPSServer():
	  return "OK"

def startVPS(vpsname):
	username = getUser()
	if username == dtcxen_user or username == vpsname:
		# Lookup the database to see if we are running a process (mkfs/fsck/etc...) on the VM instance...
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
	if username == dtcxen_user or username == vpsname:
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
	if username == dtcxen_user or username == vpsname:
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
        if username == dtcxen_user or username == vpsname:
		infos=['vpsname']
		return "OK",infos
	else:
		return "NOTOK"

def listStartedVPS():
	username = getUser()
	if username == dtcxen_user:
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
	if username == dtcxen_user or username == vpsname:
		output = commands.getstatusoutput("(echo %s; sleep 1; echo %s;) | passwd %s" % (password,password,vpsname))
		return "OK"
	else:
		return "NOTOK"

def changeVPSsoapPassword(vpsname,password):
	username = getUser()
	if username == dtcxen_user or username == vpsname:
		output = commands.getstatusoutput("htpasswd -b /etc/dtc-xen/htpasswd %s %s" % (vpsname,password))
		return "OK"
	else:
		return "NOTOK"

def changeVPSsshKey(vpsname,keystring):
	username = getUser()
	if username == dtcxen_user or username == vpsname:
		try:
			# create the directory if it doesn't exist
			if not os.path.isdir("/var/lib/dtc-xen/ttyssh_home/%s/.ssh/" % vpsname):
				os.makedirs("/var/lib/dtc-xen/ttyssh_home/%s/.ssh/" % vpsname)
			os.chown("/var/lib/dtc-xen/ttyssh_home/%s/.ssh/" % vpsname, getuserid(vpsname), getusergroup(vpsname))
			# open file stream
			filename = "/var/lib/dtc-xen/ttyssh_home/%s/.ssh/authorized_keys" % vpsname
			file = open(filename, "w")
			file.write(keystring)
			file.close()
			os.chown(filename, getuserid(vpsname), getusergroup(vpsname))
		except IOError:
			return "NOTOK - There was an error writing to", filename
		return "OK"
	else:
		return "NOTOK"

def fsckVPSpartition(vpsname):
	username = getUser()
	if username == dtcxen_user or username == vpsname:
		filename = "/var/lib/dtc-xen/states/%s" % vpsname
		status = getVPSState(vpsname)
		if status != "Not running":
			print "Status isn't good, we are already in process, or actually live"
			return "NOTOK, %s" % status
		# Write the semaphore file before proceeding
		fd2 = open(filename, 'w')
		fd2.write("fsck\n")
		print "Starting file system check for %s" % vpsname
		cmd = "/sbin/fsck.ext3"
		args = [cmd, "-p","/dev/lvm1/%s" % vpsname ]
		spawnedpid = os.spawnv(os.P_NOWAIT, cmd, args ) 
		fd2.write("%s\n" % spawnedpid)
		fd2.close()
		return "OK"
	return "NOTOK"

def changeBSDkernel(vpsname,ramsize,kerneltype,allipaddrs):
	username = getUser()
	if username == dtcxen_user or username == vpsname:
		print "Changing kernel of a BSD VM: vps: %s ram: %s kernel: %s" % (vpsname,ramsize,kerneltype)
		cmd = "dtc_change_bsd_kernel %s %s %s '%s'" % (vpsname,ramsize,kerneltype,allipaddrs)
		print cmd
		output = commands.getstatusoutput(cmd)
		return "OK"

# Take care! This time, the vpsname has to be only the number (eg XX and not xenXX)
def reinstallVPSos(vpsname,ostype,hddsize,ramsize,ipaddr,imagetype='lvm'):
	username = getUser()
	if username == dtcxen_user or username == vpsname:
		filename = "/var/lib/dtc-xen/states/xen%s" % vpsname
		print "Checking %s for mkos" % vpsname
		status = getVPSState("xen%s" % vpsname)
		if status != "Not running":
			return "NOTOK, %s" % status
		# Write the semaphore file before proceeding
		fd2 = open(filename, 'w')
		fd2.write("mkos\n")
		print "Starting reinstallation of operating system for xen%s" % vpsname
		cmd = "/usr/sbin/dtc_reinstall_os"
		args = [cmd, vpsname, hddsize, ramsize, "%s" % ipaddr, ostype, imagetype]
		print cmd
		print args
		spawnedpid = os.spawnv(os.P_NOWAIT, cmd, args )
		fd2.write("%s\n" % spawnedpid)
		fd2.close()
		return "OK, started mkos."
	return "NOTOK"

def setupLVMDisks(vpsname,hddsize,swapsize,imagetype='lvm'):
	username = getUser()
	if username == dtcxen_user or username == vpsname:
		print "Starting disk setup for xen%s: %s HHD, %s SWAP, %s imagetype" % (vpsname,hddsize,swapsize,imagetype)
		cmd = "/usr/sbin/dtc_setup_vps_disk %s %s %s %s" % (vpsname,hddsize,swapsize,imagetype)
		output = commands.getstatusoutput(cmd)
		print "Commande: %s" % cmd
		return "OK"
	else:
		return "NOTOK"

def getFreeSpace():
	free_space_disk = commands.getstatusoutput('/usr/sbin/vgdisplay_free_size')
	free_space_mem = commands.getstatusoutput('/usr/sbin/xm_info_free_memory')
	return (free_space_disk,free_space_mem)

def getuserid(user):
	import pwd
	if isinstance(user, int):
		return user
	entry = pwd.getpwnam(user)
	return entry[2]

def getusergroup(user):
	import pwd
	import grp
	return grp.getgrgid(pwd.getpwnam(user)[3])[2]

def getgroupid(group):
	import grp
	if isinstance(group, int):
		return group
	entry = grp.getgrnam(group)
	return entry[2]

def getNetworkUsage(vpsname):
	username = getUser()
	if username == dtcxen_user or username == vpsname:
		info = getVPSState(vpsname)
		id = int(xenxm.sxp.child_value(info, 'id', '-1'))
		networkDeviceName="eth0"
		if vpsname=="Domain-0":
			networkDeviceName="eth0"
		else:
			networkDeviceName="vif%s" % id
			networkDeviceName=networkDeviceName.replace("-","")
			# Rudd-O: added workaround for device matching vif-1 -> vif1 -- Damien: is this okay?
		incount = 0
		outcount = 0
		if os.path.exists("/proc/net/dev"):
			devinfoFile=open("/proc/net/dev", 'r')
			try:
				for line in devinfoFile:
					line=line.strip()
					# split the line into device, and the rest
					columns=line.split(':')
					if len(columns) == 1:
						continue
					device,stats=columns
					# strip off whitespace so we can match
					device = device.strip().split(".")[0]
					if device == networkDeviceName:
						columns=stats.split()
						incount = incount + int(columns[0])
						outcount = outcount + int(columns[8])
			finally:
				devinfoFile.close()
			return "%d,%d" % (incount,outcount)
		else:
			return "NOTOK"
			
# return the accumulated IO stat of a VPS disk and swap
def getIOUsage(vpsname):
	username = getUser()
	if username == dtcxen_user or username == vpsname:	
		disk="/dev/mapper/%s-%s" % (server_lvmname,vpsname)
		swap="/dev/mapper/%s-%sswap" % (server_lvmname,vpsname)
		
		if os.path.exists(disk):
			diskStat = os.stat(disk)
			swapStat = os.stat(swap)
			diskMinor=os.minor(diskStat.st_rdev)
			swapMinor=os.minor(swapStat.st_rdev)
	
			diskBlock="/sys/block/dm-%s/stat" % diskMinor
			diskBlockFile=open(diskBlock,'r')
			diskIOStat=0
			try:
				blockStats = diskBlockFile.readline()
				columns=blockStats.split()
				# read the disk IO total from column 11
				diskIOStat=columns[10]
			finally:
			  diskBlockFile.close()
			        
			swapBlock="/sys/block/dm-%s/stat" % swapMinor
			swapBlockFile=open(swapBlock)
			swapIOStat=0
			try:
				blockStats = swapBlockFile.readline()
				columns=blockStats.split()
        # read the swap IO total from column 11
				swapIOStat=columns[10]
			finally:
			  swapBlockFile.close()
			        
			return diskIOStat,swapIOStat
	return "NOTOK"		
	
# return the accumulated IO stat of a VPS disk and swap
def getCPUUsage(vpsname):
	username = getUser()
	if username == dtcxen_user or username == vpsname:	
		info = getVPSState(vpsname)
		return xenxm.sxp.child_value(info, 'cpu_time', '0')
	return "NOTOK"		

def getVPSState(vpsname):
	username = getUser()
        if username == dtcxen_user or username == vpsname:
        	filename = "/var/lib/dtc-xen/states/%s" % vpsname
        	print "Checking %s for getVPSState" % filename
        	try:
			print "Opening %s" % filename
	        	fd = open(filename, 'r')
			command = fd.readline()
			print "Checking fsck"
			if string.find(command,"fsck") != -1:
				fsckpid = int(fd.readline())
				print "fsck process meant to be at %s" % fsckpid
				try:
					returnstatus = os.waitpid(fsckpid, os.WNOHANG)			
					if returnstatus[1] == 0:
						print "Founded running fsck!"
						fd.close()
						return "fsck"
					else:
						print "Status is %s" % returnstatus[1]
				except:
					print "Failed to find running process... delete state file..."
				fd.close()
				os.remove(filename)
			else:			
				print "Checking mkos"
				if string.find(command,"mkos") != -1:
					mkospid = int(fd.readline())
					print "mkos process meant to be at %s" % mkospid
					try:
						returnstatus = os.waitpid(mkospid, os.WNOHANG)			
						if returnstatus[1] == 0:
							print "Founded running mkos!"
							fd.close()
							return "mkos"
						else:
							print "Status is %s" % returnstatus[1]
					except:
						print "Failed to find running process... delete state file..."
					fd.close()
					os.remove(filename)
				else:
					print "Invalid state file..."
					fd.close()
					return "NOTOK, invalid state file"
		except:
			print "No semaphore (fsck/mkos): continuing"
		try:
			if xen_version == 3:
				try:
					info = server.xend.domain(vpsname)
				except:
					info = xenxm.server.xend.domain(vpsname)
				return info
			else:
				print "Calling xenxm.server xend_domain"
				func = getattr(xenxm.server, "xend_domain")
				print "After xenxm.server"
				if func:
					print "Calling xenxm.server.xend.domain(%s)" % vpsname
					info = xenxm.server.xend_domain(vpsname)
					return info
				else:
					print "Couldn't find xend_domain method"
		except:
			return "Not running"
	else:
		return "NOTOK"

def getInstallableOS():
	folderlist = os.listdir('/usr/share/dtc-xen-os/')
	folderlist = filter(os.path.isdir, folderlist)
	return folderlist

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
					fd.close()
					print "Password matches the one in the file!"
					return 1
				else:
					fd.close()
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
soapserver.registerFunction(changeVPSsshKey)
soapserver.registerFunction(reinstallVPSos)
soapserver.registerFunction(fsckVPSpartition)
soapserver.registerFunction(changeBSDkernel)
soapserver.registerFunction(setupLVMDisks)
soapserver.registerFunction(getNetworkUsage)
soapserver.registerFunction(getIOUsage)
soapserver.registerFunction(getCPUUsage)
soapserver.registerFunction(getInstallableOS)
print "Starting dtc-xen python SOAP server at https://%s:%s/ ..." % (server_host, server_port)
while True:
	try:
		soapserver.serve_forever()
	except KeyboardInterrupt:
		print "Shutting down..."
		sys.stdout.flush()
		sys.exit(0)
	except Exception, e:
		print "Caught exception handling connection: ", e
