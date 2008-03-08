#!/usr/bin/env python
import sys, traceback
import os
import SOAPpy
import commands
#import sqlite
from StringIO import StringIO
from SOAPpy import *
import logging
import threading
try: import subprocess # FIXME maybe this wont work on older pythons?
except ImportError: subprocess = False

# debug
SOAPpy.Config.debug=1
# FIXME
# this could probably use a bit of help when run in the console instead of daemonized
# by the way, this script seems not to be detaching from the controlling pty or daemonizing itself properly.  it's WRONG.
# and it shouldn't even run as root!
logging.basicConfig(filename="/var/log/dtc-xen.log",level=logging.DEBUG)
logging.info("Starting DTC SOAP server...")

# A generalized decorator for logging exceptions
def log_exceptions(f):
   def func(*args,**kwargs):
      try:
           logging.debug("Calling function %s(%s,%s)",f.func_name,args,kwargs)
           ret = f(*args,**kwargs)
           logging.debug("Function returned %s",ret)
           return ret
      except Exception,e:
           logging.exception("Trapped exception in function call")
           raise
   func.func_name = f.func_name
   return func

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
# FIXME WHY ARE WE SILENCING THIS EXCEPTION?

# Checking for Xen version
logging.debug("Checking for Xen version")
xen_version = 2
try:
	func = getattr(xenxm.server, "xend_domain")
	if func:
		xen_version = 2
except:
	xen_version = 3

logging.debug("Detected Xen version %s",xen_version)

# read config file
p=Properties()
p.load(open('/etc/dtc-xen/soap.conf'))
server_host=p.getProperty("soap_server_host");
server_port=int(p.getProperty("soap_server_port"));
cert_passphrase=p.getProperty("soap_server_pass_phrase");
dtcxen_user=p.getProperty("soap_server_dtcxen_user");
server_lvmname=p.getProperty("soap_server_lvmname");
vpsimage_mount_point=p.getProperty("soap_server_mount_point");

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
		logging.info("Starting VPS %s",vpsname)
		localsysout = StringIO()
		localsyserr = StringIO()
		sys.stdout = localsysout
		sys.stderr = localsyserr
		try:
			xenxm.main(xmargs)
			logging.info("VPS %s started",vpsname)
			return "OK","Started %s" % vpsname
		except:
			# this is a HACK.  It should also not capture BaseException.
			sys.stdout = sys.__stdout__
			sys.stderr = sys.__stderr__
			returnString =  "NOTOK - %s %s" % (localsyserr.getvalue(), localsysout.getvalue())
			localsyserr.close()
			localsysout.close()
			logging.exception("VPS %s failed to start",vpsname)
			return returnString
	else:
		return "NOTOK"

def destroyVPS(vpsname):
	username = getUser()
	if username == dtcxen_user or username == vpsname:
		xmargs=['foo','destroy',vpsname]
		logging.info("Destroying VPS %s", vpsname)
		localsysout = StringIO()
                localsyserr = StringIO()
                sys.stdout = localsysout
                sys.stderr = localsyserr
		try:
			xenxm.main(xmargs)
			logging.info("VPS %s destroyed",vpsname)
			return "OK","Destroyed %s" % vpsname
		except:
			sys.stdout = sys.__stdout__
                        sys.stderr = sys.__stderr__
			returnString =  "NOTOK - %s %s" % (localsyserr.getvalue(), localsysout.getvalue())
			localsyserr.close()
			localsysout.close()
			logging.exception("VPS %s failed to be destroyed",vpsname)
			return returnString
	else:
		return "NOTOK"

def shutdownVPS(vpsname):
	username = getUser()
	if username == dtcxen_user or username == vpsname:
		xmargs=['foo','shutdown',vpsname]
		logging.info("Shutting VPS %s down", vpsname)
		localsysout = StringIO()
                localsyserr = StringIO()
                sys.stdout = localsysout
                sys.stderr = localsyserr
		try:
			xenxm.main(xmargs)
			logging.info("VPS %s shut down",vpsname)
			return "OK","Shut down %s" % vpsname
		except:
                        sys.stdout = sys.__stdout__
                        sys.stderr = sys.__stderr__
                        returnString =  "NOTOK - %s %s" % (localsyserr.getvalue(), localsysout.getvalue())
                        localsyserr.close() # FIXME not really needed to close the fds
                        localsysout.close() # reference count drops to zero -> boom they're closed.
			logging.exception("VPS %s failed to shut down",vpsname)
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
				logging.warn("Couldn't find xend_domains method")
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
				logging.warn("Couldn't find xend_domain method")
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
			logging.warn("Status isn't good, we are already in process, or actually live")
			return "NOTOK, %s" % status
		# Write the semaphore file before proceeding
		fd2 = open(filename, 'w')
		fd2.write("fsck\n")
		logging.info("Starting file system check for %s",vpsname)
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
		logging.info("Changing kernel of a BSD VM: vps: %s ram: %s kernel: %s",vpsname,ramsize,kerneltype)
		cmd = "dtc_change_bsd_kernel %s %s %s '%s'" % (vpsname,ramsize,kerneltype,allipaddrs)
		print cmd
		output = commands.getstatusoutput(cmd)
		return "OK"

# Take care! This time, the vpsname has to be only the number (eg XX and not xenXX)
def reinstallVPSos(vpsname,ostype,hddsize,ramsize,ipaddr,imagetype='lvm'):
	username = getUser()
	if username == dtcxen_user or username == vpsname:
		logging.info("Reinstalling %s on VPS %s",ostype,vpsname)  #maybe these should be notices if notices are below info severity
		filename = "/var/lib/dtc-xen/states/xen%s" % vpsname
		logging.debug("Checking %s for mkos",vpsname)
		status = getVPSState("xen%s" % vpsname)
		if status != "Not running":
			return "NOTOK, %s" % status
		# Write the semaphore file before proceeding
		fd2 = open(filename, 'w')
		fd2.write("mkos\n")

		log = file("%s/%s.log" % (vpsimage_mount_point, vpsname),"w",0)
		# FIXME idea: we could reuse the log isntead of a file, a stringio or something that reflects all the log activity into the logging module
		# that way everything goes into /var/log/dtc-soap-server.log
		# brilliant? you be the judge
		args = ["/usr/sbin/dtc_reinstall_os", "-v", vpsname, hddsize,
			ramsize, "%s" % ipaddr, ostype, imagetype]
			
		logging.debug("Running %s in subprocess",args)
		if subprocess:
			proc = subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT,close_fds=True,cwd="/")
			spawnedpid = proc.pid
			def wait_for_child(): # watcher thread target
				try:
					proc.wait()
					if proc.returncode != 0: level = logging.warn
					else: level = logging.debug
					level("Subprocess %s (PID %s) is done -- return code: %s",
						threading.currentThread().getName(),proc.pid,proc.returncode)
				except:
					logging.exception("Watcher thread %s died because of exception",threading.currentThread().getName())
					raise
			watcher = threading.Thread(target=wait_for_child,name="dtc_reinstall_os watcher for xen%s"%vpsname)
			watcher.setDaemon(True)
			watcher.start()
			logging.debug("Subprocess %s (PID %s) started and being watched",watcher.getName(),spawnedpid)
		else:
			spawnedpid = os.spawnv(os.P_NOWAIT, cmd, args )

		fd2.write("%s\n" % spawnedpid)
		fd2.close()
		logging.info("Reinstallation process launched")
		return "OK, started mkos."
	return "NOTOK"

def setupLVMDisks(vpsname,hddsize,swapsize,imagetype='lvm'):
	username = getUser()
	if username == dtcxen_user or username == vpsname:
		logging.info("Starting disk setup for xen%s: %s HHD, %s SWAP, %s imagetype",vpsname,hddsize,swapsize,imagetype)
		cmd = "/usr/sbin/dtc_setup_vps_disk %s %s %s %s" % (vpsname,hddsize,swapsize,imagetype)
		output = commands.getstatusoutput(cmd) # FIXME THIS IS FAIL -- it doesnt get stderr
		logging.debug("Command stdout: %s",cmd)
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
		if id == -1:
			id = int(xenxm.sxp.child_value(info, 'domid', '-1'))
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
        	logging.debug("Checking %s for getVPSState", filename)
        	try:
			logging.debug("Opening %s" , filename)
	        	fd = open(filename, 'r')
			command = fd.readline()
			logging.debug( "Checking fsck")
			if string.find(command,"fsck") != -1:
				fsckpid = int(fd.readline())
				logging.debug( "fsck process meant to be at %s" , fsckpid)
				try:
					returnstatus = os.waitpid(fsckpid, os.WNOHANG)			
					if returnstatus[1] == 0:
						logging.debug( "Founded running fsck!")
						fd.close()
						return "fsck"
					else:
						logging.debug( "Status is %s" , returnstatus[1])
				except:
					logging.debug( "Failed to find running process... delete state file...")
				fd.close()
				os.remove(filename)
			else:			
				logging.debug( "Checking mkos")
				if string.find(command,"mkos") != -1:
					mkospid = int(fd.readline())
					logging.debug( "mkos process meant to be at %s" , mkospid)
					try:
						returnstatus = os.waitpid(mkospid, os.WNOHANG)			
						if returnstatus[1] == 0:
							logging.debug( "Founded running mkos!")
							fd.close()
							return "mkos"
						else:
							logging.debug( "Status is %s" , returnstatus[1])
					except:
						logging.debug( "Failed to find running process... delete state file...")
					fd.close()
					os.remove(filename)
				else:
					logging.debug( "Invalid state file...")
					fd.close()
					return "NOTOK, invalid state file"
		except IOError,e: # FIXME WHY is this trapped?
			if e.errno == 2: logging.debug("No semaphore (fsck/mkos): continuing")
			else: raise
		try:
			if xen_version == 3:
				try:
					info = server.xend.domain(vpsname)
				except:
					info = xenxm.server.xend.domain(vpsname)
				return info
			else:
				logging.debug( "Calling xenxm.server xend_domain")
				func = getattr(xenxm.server, "xend_domain")
				logging.debug("After xenxm.server")
				if func:
					logging.debug("Calling xenxm.server.xend.domain(%s)" , vpsname)
					info = xenxm.server.xend_domain(vpsname)
					return info
				else:
					logging.debug("Couldn't find xend_domain method")
		except:
			return "Not running"
	else:
		return "NOTOK"

def getVPSInstallLog(vpsname,numlines):
	username = getUser()
        if username == dtcxen_user or username == vpsname:
		log = file("%s/%s.log" % (vpsimage_mount_point, vpsname),"r").readlines()
		numlines = int(numlines)
		if not numlines or numlines < 0: lastlines = "\n".join(log)
		else: lastlines = "\n".join(log[-numlines:])
		def toascii(char):
			if ord(char) in [10,13] or 32 <= ord(char) <= 127: return char
			return " "
		lastlines = "".join([ toascii(c) for c in lastlines ])
		return lastlines
	else:
		return "NOTOK"

def getInstallableOS():
	folderlist = os.listdir('/usr/share/dtc-xen-os/')
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
		logging.debug( "Valid user: %s", username)
		return 1
	else:
		return 0

def _authorize(*args, **kw):
	global Config
	logging.debug( "_authorize called..." )

	c = kw["_SOAPContext"]
	logging.debug( "**kw =%s" , str(kw) )

	# The socket object, useful for
	logging.debug( "Peer connected: ",  c.connection.getpeername() )

	# get authorization info from HTTP headers
	ah = c.httpheaders.get("Authorization","")

	if ah:
		# decode and analyze the string for the username and password
		# (we slice the string from 6 onwards to remove the "Basic ")
		username, password = base64.decodestring(ah[6:].strip()).split(":")
		logging.debug( "Authorization string: \"%s\"" , ah )
		# FIXME the pw should never end up the log
		logging.debug( "Username: \"%s\" Password: \"%s\"" , username, password )

		logging.debug("Loading /etc/dtc-xen/htpasswd...")
		fd = open('/etc/dtc-xen/htpasswd', 'r') 

		for line in fd:
			u, h = line.strip().split(':')
			if u == username:
				logging.debug( "Found user: %s",username)
				logging.debug( "Password from file: %s", h)
				verify_pass = crypt.crypt(password, h[:2])
				logging.debug( "Check hash password: %s",verify_pass)
				if verify_pass == h:
					fd.close()
					logging.debug( "Password matches the one in the file!")
					return 1
				else:
					fd.close()
					logging.debug("Password didn't match the one in .htpasswd")
					return 0
    
		logging.debug("Couldn't find user in password file!")
		return 0
    
	else:
		logging.debug("NO authorization information in HTTP headers, refusing.")
		return 0

def _passphrase(cert):
	logging.debug("Pass phrase faked...")
	return cert_passphrase

if not Config.SSLserver:
	### This is wrong.  IT should just raise Import Error.  FIXME
	raise RuntimeError, "this Python installation doesn't have OpenSSL and M2Crypto"

ssl_context = SSL.Context()
ssl_context.load_cert('/etc/dtc-xen/dtc-xen.cert.cert', '/etc/dtc-xen/privkey.pem', callback=_passphrase)

soapserver = SOAPpy.SOAPServer((server_host, server_port), ssl_context = ssl_context)
# No ssl 
# soapserver = SOAPpy.SOAPServer((server_host, server_port))

#let's make some functions log exceptions, arguments and retvalues
for f in [startVPS,destroyVPS,reinstallVPSos,getVPSState]: f = log_exceptions(f)
# this is required because really really really old python versions don't support decorators

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
soapserver.registerFunction(getVPSInstallLog)
logging.info("Started dtc-xen python SOAP server at https://%s:%s/ ..." , server_host, server_port)
while True:
	try:
		soapserver.serve_forever()
	except KeyboardInterrupt:
		logging.info("Shutting down due to SIGINT...")
		#FIXME this program needs to capture and handle SIGTERM gracefully as well
		sys.stdout.flush()
		sys.exit(0)
	except Exception, e:
		logging.exception("Caught exception handling connection")

logging.info("DTC SOAP server shut down")
