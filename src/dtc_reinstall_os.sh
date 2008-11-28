#!/bin/sh

set -e # DIE on errors

#########################
### MANAGE PARAMETERS ###
#########################

if [ $# -lt 5 ]; then 
	echo "Usage: $0 [ OPTIONS ] <xen id> <hdd size MB> <ram size MB> <ip address(es)> <password-to-setup> <operating-system> [ lvm | vbd ]"> /dev/stderr
	echo "-------------------------------------------------------------------------" > /dev/stderr
	echo "<operating-system> can be one of the follwing:" > /dev/stderr
	echo "debian, debian-dtc, ubuntu_dapper, centos, gentoo, slackware, xenpv, manual" > /dev/stderr
	echo "-------------------------------------------------------------------------" > /dev/stderr
	echo "Options can be in any order and are:" > /dev/stderr
	echo "                       [ -v ] : Do a more verboze install" > /dev/stderr
	echo "[ --release OS-Release-name ] : currently unused" > /dev/stderr
	echo "-------------------------------------------------------------------------" > /dev/stderr
	echo "Network option to setup inside the guest VPS:" > /dev/stderr
	echo "        [ --netmask netmask ] : guest OS netmask" > /dev/stderr
	echo "        [ --network network ] : guest OS network" > /dev/stderr
	echo "    [ --broadcast broadcast ] : guest OS broadcast" > /dev/stderr
	echo "        [ --gateway gateway ] : guest OS network gateway" > /dev/stderr
	echo "-------------------------------------------------------------------------" > /dev/stderr
	echo "Options specific to Xen PV guests:" > /dev/stderr
	echo "       [ --vnc-pass VNCPASS ] : VNC password for the physical console" > /dev/stderr
	echo "      [ --boot-iso file.iso ] : CDROM device to boot on" > /dev/stderr
	echo "-------------------------------------------------------------------------" > /dev/stderr
	echo "Example: $0 09 3072 64 1.2.3.4 debian" > /dev/stderr
	exit 1
fi

# Source the configuration in the config file!
. /etc/dtc-xen/dtc_create_vps.conf.sh
# Some defaults if not present in the conf file...
if [ "$LVMNAME" = "" ] ; then LVMNAME=lvm1 ; fi
if [ "$DEBIAN_RELEASE" = "" ] ; then DEBIAN_RELEASE=etch ; fi

# Manage options in any order...
REDIRECTOUTPUT=true
VNC_PASSWORD=`dd if=/dev/random bs=64 count=1 2>|/dev/null | md5sum | cut -d' ' -f1`
for i in $@ ; do
	case "$1" in
	"-v")
		REDIRECTOUTPUT=false
		shift
		;;
	"--vnc-pass")
		VNC_PASSWORD=$2
		shift
		shift
		;;
	"--boot-iso")
		BOOT_ISO=$2
		shift
		shift
		;;
	"--release")
		RELEASE=$2
		shift
		shift
		;;
	"--netmask")
		NETMASK=$2
		shift
		shift
		;;
	"--network")
		NETWORK=$2
		shift
		shift
		;;
	"--broadcast")
		BROADCAST=$2
		shift
		shift
		;;
	"--gateway")
		GATEWAY=$2
		shift
		shift
		;;
	esac
done

VPSGLOBPATH=${VPS_MOUNTPOINT}
#KERNELNAME="2.6.11.12-xenU"
KERNELPATH="/boot/vmlinuz-${KERNELNAME}"
BSDKERNELPATH="/boot/netbsd-INSTALL_XENU"
#DEBIAN_BINARCH=i386

# Things that most of then time don't change
VPSNUM=$1
VPSNAME=xen${VPSNUM}
VPSHOSTNAME=xen${NODE_NUM}${VPSNUM}
VPSHDD=$2
VPSMEM=$3
ALL_IPADDRS=$4
PASSWORD=$5
DISTRO=$6
IMAGE_TYPE=$7

# Configure the first IP only (the user can setup the others)
IPADDR=`echo ${ALL_IPADDRS} | cut -d' ' -f1`

calcMacAddr () {
	CHARCNT=`echo -n ${NODE_NUM} | wc -m`
	if [ "${CHARCNT}" = "5" ] ; then
		MINOR_NUM=`echo ${NODE_NUM} | awk '{print substr($0,4,2)}'`
		MAJOR_NUM=`echo ${NODE_NUM} | awk '{print substr($0,2,2)}'`
		MEGA_NUM=`echo ${NODE_NUM} | awk '{print substr($0,1,1)}'`
	else
		MINOR_NUM=`echo ${NODE_NUM} | awk '{print substr($0,3,2)}'`
		MAJOR_NUM=`echo ${NODE_NUM} | awk '{print substr($0,1,2)}'`
		MEGA_NUM="0"
	fi
	MAC_ADDR=`echo 00:00:2$MEGA_NUM:$MAJOR_NUM:$MINOR_NUM:$VPSNUM`
}
calcMacAddr

# default to lvm type for backwards compatibility
if [ -z "$IMAGE_TYPE" ]; then
	IMAGE_TYPE=lvm
fi


FOUNDED_ARCH=`uname -m`

case "$FOUNDED_ARCH" in
	i386)
		DEBIAN_BINARCH=i386
		CENTOS_BINARCH=i386
		;;
	i436)
		DEBIAN_BINARCH=i386
		CENTOS_BINARCH=i386
		;;
	i586)
		DEBIAN_BINARCH=i386
		CENTOS_BINARCH=i386
		;;
	i686)
		DEBIAN_BINARCH=i386
		CENTOS_BINARCH=i386
		;;
	x86_64)
		DEBIAN_BINARCH=amd64
		CENTOS_BINARCH=x86_64
		;;
	*)
		echo "Unrecognized arch: exiting!"
		exit 1
		;;
esac

# default distro to debian
if [ -z "$DISTRO" ]; then
	DISTRO=debian
fi

LVCREATE=/sbin/lvcreate
MKFS=/sbin/mkfs.ext3
MKDIR=/bin/mkdir
MKSWAP=/sbin/mkswap
MOUNT=/bin/mount
UMOUNT=/bin/umount
DEBOOTSTRAP=/usr/sbin/debootstrap

######################################
### REDIRECTION OF STANDARD OUTPUT ###
######################################

# redirect stdout and stderr to log files, so we can see what happened during install
if [ "$REDIRECTOUTPUT" = "true" ] ; then
	echo "Redirecting standard output to $VPSGLOBPATH/$VPSNUM.stdout..."
	echo "Redirecting standard error to $VPSGLOBPATH/$VPSNUM.stderr..."
	if [ -e $VPSGLOBPATH/$VPSNUM.stdout ]; then
		mv $VPSGLOBPATH/$VPSNUM.stdout $VPSGLOBPATH/$VPSNUM.stdout.old
	fi
	if [ -e $VPSGLOBPATH/$VPSNUM.stderr ]; then
		mv $VPSGLOBPATH/$VPSNUM.stderr $VPSGLOBPATH/$VPSNUM.stderr.old
	fi
	
	exec 1>$VPSGLOBPATH/$VPSNUM.stdout
	exec 2>$VPSGLOBPATH/$VPSNUM.stderr
fi


############################
### FORMAT THE PARTITION ###
############################

echo "Seleted ${VPSNAME}: ${VPSHDD}MB HDD and ${VPSMEM}MB RAM";
if [ "$DISTRO" = "xenpv" ] ; then
	echo "Not formating disks, xenpv will use emulated hard drives."
elif [ "$DISTRO" = "netbsd" -o "$DISTRO" = "xenpv" ] ; then
	echo "Not formating disks, NetBSD will use emulated hard drives."
else
	echo "Creating disks..."

	set +e
	$UMOUNT ${VPSGLOBPATH}/${VPSNUM} 2> /dev/null
	rmdir ${VPSGLOBPATH}/${VPSNUM} 2> /dev/null
	set -e

	$MKDIR -p ${VPSGLOBPATH}/${VPSNUM}
	if [ "$IMAGE_TYPE" = "lvm" ]; then
		$MKFS -q /dev/${LVMNAME}/${VPSNAME}
	#	$LVCREATE -L${VPSMEM} -n${VPSNAME}swap ${LVMNAME}
		$MKSWAP /dev/${LVMNAME}/${VPSNAME}swap

		if grep ${VPSNAME} /etc/fstab >/dev/null ; then
			echo "LV already exists in fstab: skipping"
		else
			echo "/dev/mapper/${LVMNAME}-${VPSNAME}  ${VPSGLOBPATH}/${VPSNUM} ext3    defaults,noauto 0 0" >>/etc/fstab
		fi

	else
		# support for file backed VPS
		# Create files for hdd and swap (only if they don't exist)
		if [ ! -e $VPSGLOBPATH/${VPSNAME}.img ]; then
			dd if=/dev/zero of=$VPSGLOBPATH/${VPSNAME}.img bs=1G seek=${VPSHDD} count=1
		fi
		$MKFS -F $VPSGLOBPATH/${VPSNAME}.img
		if [ ! -e $VPSGLOBPATH/${VPSNAME}.swap.img ]; then
			dd if=/dev/zero of=$VPSGLOBPATH/${VPSNAME}.swap.img bs=1M seek=${VPSMEM} count=1
		fi
		$MKSWAP $VPSGLOBPATH/${VPSNAME}.swap.img
		if grep ${VPSNAME} /etc/fstab >/dev/null ; then
			echo "LoopMount already exists in fstab: skipping"
		else
			echo "$VPSGLOBPATH/${VPSNAME}.img  ${VPSGLOBPATH}/${VPSNUM}  ext3	defaults,noauto,loop 0 0" >>/etc/fstab
		fi
	fi

	echo "Mounting..."
	$MOUNT ${VPSGLOBPATH}/${VPSNUM}
fi

####################
### BOOTSTRAPING ###
####################

echo "Bootstraping..."
# default CENTOS_RELEASE is centos4

# get the most recent centos release.  it WILL FAIL once centos version hits 10.  But, hell, I'm a hacky hack.
CENTOS_DIR=`ls -d /usr/src/centos* 2> /dev/null | tr ' ' '\n' | sort -r | head -1`
if [ "$DISTRO" = "xenpv" -o "$DISTRO" = "netbsd" ] ; then
	echo "There's nothing to bootstrap, as you will use the provided distribution installer in this case."
elif [ "$DISTRO" = "centos" ] ; then
	/usr/sbin/dtc_install_centos /var/lib/dtc-xen/yum "$VPSGLOBPATH/$VPSNUM"
elif [ "$DISTRO" = "debian" -o "$DISTRO" = "debian-dtc" ] ; then
	if [ ${DEBIAN_BINARCH} = "i386" ] ; then
		ADD_LIBC="libc6-xen,"
	else
		ADD_LIBC=""
	fi
	echo $DEBOOTSTRAP --verbose --include=${ADD_LIBC}module-init-tools,locales,udev --arch ${DEBIAN_BINARCH} ${DEBIAN_RELEASE} ${VPSGLOBPATH}/${VPSNUM} ${DEBIAN_REPOS}
	$DEBOOTSTRAP --verbose --include=${ADD_LIBC}module-init-tools,locales,udev --arch ${DEBIAN_BINARCH} ${DEBIAN_RELEASE} ${VPSGLOBPATH}/${VPSNUM} ${DEBIAN_REPOS} || debret=$?
	if [ "$debret" != "" ]; then
		echo "Failed to install $DISTRO via bootstrap!!"
		exit $debret
	fi
else
	if [ -x /usr/share/dtc-xen-os/${DISTRO}/install_os ] ; then
		/usr/share/dtc-xen-os/${DISTRO}/install_os ${VPSGLOBPATH} ${VPSNUM}
	else
		echo "Currently, you will have to manually install your distro... sorry :)"
		echo "The filesystem is mounted on ${VPSGLOBPATH}/${VPSNUM}"
		echo "Remember to unmount (umount ${VPSGLOBPATH}/${VPSNUM}) before booting the OS"
		echo "Cheers!"
		exit
	fi
fi

########################
### OS CUSTOMIZATION ###
########################

echo "Customizing vps fstab, hosts, hostname, and capability kernel module..."
if [ "$DISTRO" = "debian" -o "$DISTRO" = "debian-dtc" -o "$DISTRO" = "centos" ] ; then
	/usr/sbin/dtc-xen_domUconf_standard ${VPSGLOBPATH}/${VPSNUM} ${VPSHOSTNAME} ${NODE_DOMAIN_NAME} ${KERNELNAME} ${IPADDR}
	if [ "$DISTRO" = "debian" -o "$DISTRO" = "debian-dtc" ] ; then
		sed "s/VPS_HOSTNAME/${VPSHOSTNAME}/" /etc/dtc-xen/motd >${VPSGLOBPATH}/${VPSNUM}/etc/motd.tail
	fi
else
	if [ -x /usr/share/dtc-xen-os/${DISTRO}/custom_os ] ; then
		/usr/share/dtc-xen-os/${DISTRO}/custom_os ${VPSGLOBPATH}/${VPSNUM} ${VPSHOSTNAME} ${NODE_DOMAIN_NAME} ${KERNELNAME} ${IPADDR}
	fi
fi

####################################
### NETWORK CONFIG CUSTOMIZATION ###
####################################

# handle the network setup
if [ "$DISTRO" = "netbsd" -o "$DISTRO" = "xenpv" ] ; then
	echo "Nothing to do: it's BSD or xenpv!"
elif [ "$DISTRO" = "centos" -o "$DISTRO" = "centos42" ] ; then
	/usr/sbin/dtc-xen_domUconf_network_redhat ${VPSGLOBPATH}/${VPSNUM} ${IPADDR} ${NETMASK} ${NETWORK} ${BROADCAST} ${GATEWAY}
elif [ "$DISTRO" = "debian" -o "$DISTRO" = "debian-dtc" ] ; then
	/usr/sbin/dtc-xen_domUconf_network_debian ${VPSGLOBPATH}/${VPSNUM} ${IPADDR} ${NETMASK} ${NETWORK} ${BROADCAST} ${GATEWAY}

	cp /etc/apt/sources.list ${VPSGLOBPATH}/${VPSNUM}/etc/apt
else
	if [ -x /usr/share/dtc-xen-os/${DISTRO}/setup_network ] ; then
		/usr/share/dtc-xen-os/${DISTRO}/setup_network ${VPSGLOBPATH}/${VPSNUM} ${IPADDR} ${NETMASK} ${NETWORK} ${BROADCAST} ${GATEWAY}
	else
		echo "Not implemented for other distros yet"
		exit 1
	fi
fi

#################################
### XEN STARTUP FILE CREATION ###
#################################

if [ "$DISTRO" = "xenpv" ] ; then
	echo -n "kernel = \"/usr/lib/xen/boot/hvmloader\"
builder = 'hvm'
memory = ${VPSMEM}
name = \"${VPSNAME}\"
vcpus=1
pae=0
acpi=0
apic=0
vif = [ 'type=ioemu, mac=${MAC_ADDR}, ip=${ALL_IPADDRS}' ]
disk=[ 'phy:/dev/mapper/${LVMNAME}-xen${VPSNUM},ioemu:hda,w'" >/etc/xen/${VPSNAME}
	# Add all *.iso files to the config file
	HDDLIST="bcdefghijklmnopqrstuvwxyz"
	INCREMENT=1
	for i in `find /var/lib/dtc-xen/ttyssh_home/xen${VPSNUM} -mindepth 1 -maxdepth 1 -iname '*.iso' | cut -d'/' -f5 | tr \\\r\\\n ,\ ` ; do
		DRIVE_LETTER=`echo ${HDDLIST} | awk '{print substr($0,$INCREMENT,1)}'`
		INCREMENT=$(( $INCREMENT + 1))
		echo -n ,\'file:/var/lib/dtc-xen/ttyssh_home/xen${VPSNUM}/$i,hd${DRIVE_LETTER}:cdrom,r\' >>/etc/xen/${VPSNAME}
		echo $i
	done
	# Set the VPN password
	echo " ]
vfb = [ \"type=vnc,vncdisplay=21,vncpasswd=XXXX\" ]" >>/etc/xen/${VPSNAME}
	# Set the boot cd if variable is set
	if [ -z "${BOOT_ISO}" -a -e /var/lib/dtc-xen/ttyssh_home/xen${VPSNUM}/${BOOT_ISO} ] ; then
		echo "cdrom=\"/var/lib/dtc-xen/ttyssh_home/xen${VPSNUM}/${BOOT_ISO}\"
boot=\"d\"
nographic=0
vnc=1
stdvga=1" >>/etc/xen/${VPSNAME}
	# Otherwise boot on the HDD
	else
		echo "boot=\"c\"
nographic=1" >>/etc/xen/${VPSNAME}
	fi
	echo "serial='pty'" >>/etc/xen/${VPSNAME}
elif [ "$DISTRO" = "netbsd" ] ; then
	echo "kernel = \"${BSDKERNELPATH}\"
memory = ${VPSMEM}
name = \"${VPSNAME}\"
vif = [ 'mac=${MAC_ADDR}, ip=${ALL_IPADDRS}' ]
" >/etc/xen/${VPSNAME}
	if [ "$IMAGE_TYPE" = "lvm" ]; then
		echo "disk = [ 'phy:/dev/mapper/${LVMNAME}-xen${VPSNUM},0x3,w' ]
" >>/etc/xen/${VPSNAME}
	else
		echo "disk = [ 'file:$VPSGLOBPATH/${VPSNAME}.img,0x301,w' ]
" >>/etc/xen/${VPSNAME}
	fi
else
	echo "kernel = \"${KERNELPATH}\"
memory = ${VPSMEM}
name = \"${VPSNAME}\"
#cpu = -1   # leave to Xen to pick
vif = [ 'mac=${MAC_ADDR}, ip=${ALL_IPADDRS}' ]
" > /etc/xen/${VPSNAME}
	if [ "$IMAGE_TYPE" = "lvm" ]; then
		echo "disk = [ 'phy:/dev/mapper/${LVMNAME}-xen${VPSNUM},sda1,w','phy:/dev/mapper/${LVMNAME}-xen${VPSNUM}swap,sda2,w' ]
" >> /etc/xen/${VPSNAME}
	else
		echo "disk = [ 'file:$VPSGLOBPATH/${VPSNAME}.img,sda1,w','file:$VPSGLOBPATH/${VPSNAME}.swap.img,sda2,w' ]
" >> /etc/xen/${VPSNAME}
	fi
	if [ "$DISTRO" = "slackware" ]; then
		echo "root = \"/dev/sda1 ro\"
# Sets runlevel 3.
extra = \"3 TERM=xterm xencons=tty console=tty1\"
" >>/etc/xen/${VPSNAME}
	else
		echo "root = \"/dev/sda1 ro\"
# Sets runlevel 4.
extra = \"4 TERM=xterm xencons=tty console=tty1\"
" >>/etc/xen/${VPSNAME}
	fi
fi
if [ ! -e /etc/xen/auto/${VPSNAME} ] ; then
	ln -s ../${VPSNAME} /etc/xen/auto/${VPSNAME}
fi

########################
### SOME LAST THINGS ###
########################

# need to install 2.6 compat stuff for centos3
if [ "$DISTRO" = "centos" -a "$CENTOS_RELEASE" = "centos3" ]; then
	mkdir -p ${VPSGLOBPATH}/${VPSNUM}/tmp
	wget -O ${VPSGLOBPATH}/${VPSNUM}/tmp/yum.conf.mini ftp://ftp.pasteur.fr/pub/BIS/tru/2.6_CentOS-3/yum.conf.mini
	chroot ${VPSGLOBPATH}/${VPSNUM} yum -c /tmp/yum.conf.mini -y update	
	chroot ${VPSGLOBPATH}/${VPSNUM} yum -c /tmp/yum.conf.mini install initscripts_26
	chroot ${VPSGLOBPATH}/${VPSNUM} rm /tmp/yum.conf.mini
fi

# nuke the root password in CentOS 5 and above
# WARNING: for some reason CentOS is not using shadow passwords
if [ "$DISTRO" = "centos" ] ; then
	chroot ${VPSGLOBPATH}/${VPSNUM} usermod -p "" root
fi

if [ "$DISTRO" = "debian-dtc" ] ; then
	cp /usr/share/dtc-xen/dtc-panel_autodeploy.sh ${VPSGLOBPATH}/${VPSNUM}/root/dtc-panel_autodeploy
	chmod +x ${VPSGLOBPATH}/${VPSNUM}/root/dtc-panel_autodeploy
	cp /usr/share/dtc-xen/selection_config_file ${VPSGLOBPATH}/${VPSNUM}/root
	echo "#!/bin/sh

cd /root
/root/dtc-panel_autodeploy ${PASSWORD}

rm /etc/rc2.d/S99dtc-panel_autodeploy
rm /etc/rc3.d/S99dtc-panel_autodeploy
rm /etc/rc4.d/S99dtc-panel_autodeploy
rm /etc/rc5.d/S99dtc-panel_autodeploy
rm /etc/init.d/dtc-panel_autodeploy
" >${VPSGLOBPATH}/${VPSNUM}/etc/init.d/dtc-panel_autodeploy
	chmod +x ${VPSGLOBPATH}/${VPSNUM}/etc/init.d/dtc-panel_autodeploy
	ln -s ../init.d/dtc-panel_autodeploy ${VPSGLOBPATH}/${VPSNUM}/etc/rc2.d/S99dtc-panel_autodeploy
	ln -s ../init.d/dtc-panel_autodeploy ${VPSGLOBPATH}/${VPSNUM}/etc/rc3.d/S99dtc-panel_autodeploy
	ln -s ../init.d/dtc-panel_autodeploy ${VPSGLOBPATH}/${VPSNUM}/etc/rc4.d/S99dtc-panel_autodeploy
	ln -s ../init.d/dtc-panel_autodeploy ${VPSGLOBPATH}/${VPSNUM}/etc/rc5.d/S99dtc-panel_autodeploy
fi

#######################
### UMOUNT AND EXIT ###
#######################

echo "Unmounting proc and filesystem root..."
$UMOUNT ${VPSGLOBPATH}/${VPSNUM}/proc 2> /dev/null || /bin/true
$UMOUNT ${VPSGLOBPATH}/${VPSNUM}

echo "Install script finished"
exit 0
