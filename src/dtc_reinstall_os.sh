#!/bin/sh

if [ $# -lt 3 ]; then 
	echo "Usage: $0 <xen id> <hdd size> <ram size> <ip address> [debian/ubuntu_dapper/centos/gentoo/manual] [lvm/vbd]"
	exit
fi


# Things that often change

# Source the configuration in the config file!
. /etc/dtc-xen/dtc_create_vps.conf.sh

#NODE_NUM=6501
#DEBIAN_REPOS="http://65.apt-proxy.gplhost.com:9999/debian"
#NETMASK=255.255.255.0
#NETWORK=202.124.18.0
#BROADCAST=202.124.18.255
#GATEWAY=202.124.18.1

# Things that might change
#LVMNAME=lvm1
VPSGLOBPATH=/xen
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
DISTRO=$5
IMAGE_TYPE=$6

# redirect stdout and stderr to log files, so we can see what happened during install

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

# default to lvm type for backwards compatibility
if [ -z ""$IMAGE_TYPE ]; then
	IMAGE_TYPE=lvm
fi

# Configure the first IP only (the user can setup the others)
IPADDR=`echo ${ALL_IPADDRS} | cut -d' ' -f1`

function calcMacAddr {
	CHARCNT=`echo -n ${NODE_NUM} | wc -m`
	if [ ""${CHARCNT} = "5" ] ; then
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

FOUNDED_ARCH=`uname -m`

case "$FOUNDED_ARCH" in
	i386)
		DEBIAN_BINARCH=i386
		;;
	i436)
		DEBIAN_BINARCH=i386
		;;
	i586)
		DEBIAN_BINARCH=i386
		;;
	i686)
		DEBIAN_BINARCH=i386
		;;
	x86_64)
		DEBIAN_BINARCH=amd64
		;;
	*)
		echo "Unrecognized arch: exiting!"
		exit 1
		;;
esac

# default distro to debian
if [ -z ""$DISTRO ]; then
	DISTRO=debian
fi

LVCREATE=/sbin/lvcreate
MKFS=/sbin/mkfs.ext3
MKDIR=/bin/mkdir
MKSWAP=/sbin/mkswap
MOUNT=/bin/mount
DEBOOTSTRAP=/usr/sbin/debootstrap

echo "Seleted ${VPSNAME}: ${VPSHDD}G HDD and ${VPSMEM}MB RAM";
if [ ""$DISTRO = "netbsd" ] ; then
	echo "Not creating disks: NetBSD!"
else
	echo "Creating disks..."

	if [ ""$IMAGE_TYPE = "lvm" ]; then
		$MKFS /dev/${LVMNAME}/${VPSNAME}
		$MKDIR -p ${VPSGLOBPATH}/${VPSNUM}
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
		if [ ! -e $MKSWAP $VPSGLOBPATH/${VPSNAME}.swap.img ]; then
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

echo "Bootstraping..."
# default CENTOS_RELEASE is centos4
CENTOS_RELEASE=centos4
if [ ""$DISTRO = "centos" ] ; then
	# first check to see if we have a centos4 archive
	# if not, revert to centos3 (to maintain backwards compatibility)
	if [ ! -e /usr/src/$CENTOS_RELEASE ]; then
		CENTOS_RELEASE=centos3
	fi

	if [ ! -e /usr/src/$CENTOS_RELEASE ] ; then
		echo "Please install $CENTOS_RELEASE rpms in /usr/src"
		echo "This can be done using: rpmstrap --verbose --download-only $CENTOS_RELEASE /usr/src/$CENTOS_RELEASE"
		exit
	fi
	if [ ! -e /usr/bin/rpmstrap ] ; then
		echo "Please install rpmstrap from http://rpmstrap.pimpscript.net/"
		exit
	fi
	if [ ""$DEBIAN_BINARCH = "amd64" ] ; then
		/usr/bin/rpmstrap --verbose --arch x86_64 --local-source /usr/src/$CENTOS_RELEASE $CENTOS_RELEASE ${VPSGLOBPATH}/${VPSNUM}
	else
		/usr/bin/rpmstrap --verbose --local-source /usr/src/$CENTOS_RELEASE $CENTOS_RELEASE ${VPSGLOBPATH}/${VPSNUM}
	fi
elif [ ""$DISTRO = "debian" ] ; then
	echo $DEBOOTSTRAP --include=module-init-tools,hotplug,udev --arch ${DEBIAN_BINARCH} sarge ${VPSGLOBPATH}/${VPSNUM} ${DEBIAN_REPOS}
	$DEBOOTSTRAP --include=module-init-tools,hotplug,udev --arch ${DEBIAN_BINARCH} sarge ${VPSGLOBPATH}/${VPSNUM} ${DEBIAN_REPOS}
	if [ $? != 0 ]; then
		echo "Failed to install debian via bootstrap!!"
		exit 1
	fi
elif [ ""$DISTRO = "ubuntu_dapper" ] ; then
	$DEBOOTSTRAP --include=module-init-tools,udev --arch i386 dapper ${VPSGLOBPATH}/${VPSNUM} http://archive.ubuntu.com/ubuntu
elif [ ""$DISTRO = "gentoo" ]; then
	GENTOO_STAGE3_ARCHIVE="stage3-i686-2006.1.tar.bz2"
	GENTOO_STAGE3_BASEURL="http://mirror.gentoo.gr.jp/releases/x86/2006.1/stages/"
	# detect if it requires an amd64 distro
	if [ ""${DEBIAN_BINARCH} = "amd64" ]; then
		GENTOO_STAGE3_ARCHIVE="stage3-amd64-2006.1.tar.bz2"
		GENTOO_STAGE3_BASEURL="http://mirror.gentoo.gr.jp/releases/amd64/2006.1/stages/"
	fi

	if [ ! -e /usr/src/gentoo/$GENTOO_STAGE3_ARCHIVE ]; then
		echo "Please download the gentoo stage3 from $GENTOO_STAGE3_BASEURL$GENTOO_STAGE3_ARCHIVE"
		echo "Or another gentoo mirror"
		if [ -e /usr/src/gentoo/stage3-x86-2006.0.tar.bz2 ]; then
			# if we find an old archive here, use this as a fall back
			GENTOO_STAGE3_ARCHIVE=stage3-x86-2006.0.tar.bz2
		else
			exit
		fi
	fi
	tar -xjpf /usr/src/gentoo/$GENTOO_STAGE3_ARCHIVE -C ${VPSGLOBPATH}/${VPSNUM}
	# grab the latest portage
	pushd /usr/src/gentoo
	wget -N http://mirror.gentoo.gr.jp/snapshots/portage-latest.tar.bz2.md5sum
	wget -N http://mirror.gentoo.gr.jp/snapshots/portage-latest.tar.bz2
	md5sum -c portage-latest.tar.bz2.md5sum
	tar -xjpf portage-latest.tar.bz2 -C ${VPSGLOBPATH}/${VPSNUM}/usr/
	popd
	# need to reset the root password
	sed -e 's/root:\*:/root::/' ${VPSGLOBPATH}/${VPSNUM}/etc/shadow > ${VPSGLOBPATH}/${VPSNUM}/etc/shadow.tmp
	mv ${VPSGLOBPATH}/${VPSNUM}/etc/shadow.tmp ${VPSGLOBPATH}/${VPSNUM}/etc/shadow
else
	echo "Currently, you will have to manually install your distro... sorry :)"
	echo "The filesystem is mounted on ${VPSGLOBPATH}/${VPSNUM}"
	echo "Remember to unmount (umount ${VPSGLOBPATH}/${VPSNUM}) before booting the OS"
	echo "Cheers!"
	exit
fi
if [ ""$DISTRO = "netbsd" ] ; then
	echo "Nothing to do: it's BSD"
else
	echo "Customizing vps..."
	ETC=${VPSGLOBPATH}/${VPSNUM}/etc
	echo "/dev/sda1       /       ext3    errors=remount-ro       0       0
proc            /proc   proc    defaults                0       0
/dev/sda2       none    swap    sw                      0       0
" >${ETC}/fstab
	echo "${VPSHOSTNAME}" >${ETC}/hostname
	echo "127.0.0.1	localhost.localdomain   localhost
202.124.17.46	dtc.node6503.gplhost.com
66.251.193.20	dtc.gplhost.com
${IPADDR}	dtc.${VPSHOSTNAME}.gplhost.com ${VPSHOSTNAME}.gplhost.com ${VPSHOSTNAME}

# The following lines are desirable for IPv6 capable hosts
::1	ip6-localhost ip6-loopback
fe00::0	ip6-localnet
ff00::0	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
ff02::3	ip6-allhosts
" >${ETC}/hosts
	echo "
  ______    ___________________     GPL.Host_____    ____ ___|   .__
 (  ___/___(____     /  |______|   |_______(    /___(  _/_\___   __/
 |  \___  \_  |/    /   |\    \_   ____  \_   ___ \_______  \|   |
 |   |/    /  _____/    |/     /   |  /   /   |/   /  s!|/   /   |
 |_________\  |    |__________/|___| /   /|________\_________\GPL|
 Opensource dr|ven hosting worldwide____/http://gplhost.com  |HOST

${VPSHOSTNAME}

" >${ETC}/motd
	cp /root/.bashrc ${VPSGLOBPATH}/${VPSNUM}/root

	echo "#!/bin/bash

MODPROBE=/sbin/modprobe
case \"\$1\" in
	start)
		echo \"Adding linux default capabilities module\"
		\$MODPROBE capability
		echo \"done!\"
		;;
	stop)
		;;
	restart)
		\$0 start
		;;
	reload|force-reload)
		;;
	*)
		echo \"Usage: /etc/init.d/capabilities {start|stop|restart|reload}\"
		exit 1
esac
exit 0

 " >${ETC}/init.d/capabilities
	chmod +x ${ETC}/init.d/capabilities
	ln -s ../init.d/capabilities ${ETC}/rc0.d/K19capabilities
	ln -s ../init.d/capabilities ${ETC}/rc1.d/K19capabilities
	ln -s ../init.d/capabilities ${ETC}/rc6.d/K19capabilities
	ln -s ../init.d/capabilities ${ETC}/rc2.d/S19capabilities
	ln -s ../init.d/capabilities ${ETC}/rc3.d/S19capabilities
	ln -s ../init.d/capabilities ${ETC}/rc4.d/S19capabilities
	ln -s ../init.d/capabilities ${ETC}/rc5.d/S19capabilities
fi

# handle the network setup
if [ ""$DISTRO = "netbsd" ] ; then
	echo "Nothing to do: it's BSD!"
elif [ ""$DISTRO = "centos" ] ; then
	# Configure the eth0
	echo "DEVICE=eth0
BOOTPROTO=static
BROADCAST=${BROADCAST}
IPADDR=${IPADDR}
NETMASK=${NETMASK}
NETWORK=${NETWORK}
ONBOOT=yes
" >${ETC}/sysconfig/network-scripts/ifcfg-eth0
	# Set the gateway file
	echo "NETWORKING=yes
HOSTNAME=xen${NODE_NUM}${VPSNUM}
GATEWAY=${GATEWAY}
" >${ETC}/sysconfig/network
	# Set the resolv.conf
	cp /etc/resolv.conf ${ETC}/resolv.conf
elif [ ""$DISTRO = "gentoo" ] ; then
	cp -L /etc/resolv.conf ${ETC}/resolv.conf	
	echo "config_eth0=( \"${IPADDR} netmask ${NETMASK} broadcast ${BROADCAST}\" )
routes_eth0=(
       \"default via ${GATEWAY}\"
)
" > ${ETC}/conf.d/net

chroot ${VPSGLOBPATH}/${VPSNUM} rc-update add net.eth0 default

elif [ ""$DISTRO = "debian" ] ; then
		cp /etc/apt/sources.list ${VPSGLOBPATH}/${VPSNUM}/etc/apt
		echo "auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
	address ${IPADDR}
	netmask ${NETMASK}
	network ${NETWORK}
	broadcast ${BROADCAST}
	gateway ${GATEWAY}
" >${ETC}/network/interfaces
elif [ ""$DISTRO = "ubuntu_dapper" ] ; then
	echo "deb http://archive.ubuntu.com/ubuntu/ dapper main restricted
deb-src http://archive.ubuntu.com/ubuntu/ dapper main restricted
		
deb http://archive.ubuntu.com/ubuntu/ dapper-updates main restricted
deb-src http://archive.ubuntu.com/ubuntu/ dapper-updates main restricted
" >${VPSGLOBPATH}/${VPSNUM}/etc/apt/sources.list
		echo "auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
	address ${IPADDR}
	netmask ${NETMASK}
	network ${NETWORK}
	broadcast ${BROADCAST}
	gateway ${GATEWAY}
" >${ETC}/network/interfaces
else
	echo "Not implemented for other distros yet"
	exit
fi

if [ ""$DISTRO = "netbsd" ] ; then
	echo "kernel = \"${BSDKERNELPATH}\"
memory = ${VPSMEM}
name = \"${VPSNAME}\"
vif = [ 'mac=${MAC_ADDR}, ip=${ALL_IPADDRS}' ]
" >/etc/xen/${VPSNAME}
	if [ ""$IMAGE_TYPE = "lvm" ]; then
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
	if [ ""$IMAGE_TYPE = "lvm" ]; then
		echo "disk = [ 'phy:/dev/mapper/${LVMNAME}-xen${VPSNUM},sda1,w','phy:/dev/mapper/${LVMNAME}-xen${VPSNUM}swap,sda2,w' ]
" >> /etc/xen/${VPSNAME}
	else
		echo "disk = [ 'file:$VPSGLOBPATH/${VPSNAME}.img,sda1,w','file:$VPSGLOBPATH/${VPSNAME}.swap.img,sda2,w' ]
" >> /etc/xen/${VPSNAME}
	fi
	echo "root = \"/dev/sda1 ro\"
# Sets runlevel 4.
extra = \"4\"
" >>/etc/xen/${VPSNAME}
fi

if [ ! -e /etc/xen/auto/${VPSNAME} ] ; then
	ln -s ../${VPSNAME} /etc/xen/auto/${VPSNAME}
fi

if [ ""$DISTRO = "netbsd" ] ; then
	echo "Not coping modules: it's BSD!"
else

	# we need to do MAKEDEV for all linux distroes
	# Make all the generic devices (inclusive of sda1 and sda2)
	mkdir -p ${VPSGLOBPATH}/${VPSNUM}/dev/
	echo "Making VPS devices with MAKEDEV generic"
	pushd ${VPSGLOBPATH}/${VPSNUM}/dev/; /sbin/MAKEDEV generic; popd
	echo "Copying modules..."
	mv ${VPSGLOBPATH}/${VPSNUM}/lib/tls ${VPSGLOBPATH}/${VPSNUM}/lib/tls.disabled
	# create the /lib/modules if it doesn't exist
	if [ ! -e ${VPSGLOBPATH}/${VPSNUM}/lib/modules ]; then 
		$MKDIR -p ${VPSGLOBPATH}/${VPSNUM}/lib/modules
	fi
	cp -auxvf /lib/modules/${KERNELNAME} ${VPSGLOBPATH}/${VPSNUM}/lib/modules
	cp -L ${KERNELPATH} ${VPSGLOBPATH}/${VPSNUM}/boot
	cp -L /boot/System.map-${KERNELNAME} ${VPSGLOBPATH}/${VPSNUM}/boot
	# symlink the System.map and kernel
	ln -s /boot/System.map-${KERNELNAME} ${VPSGLOBPATH}/${VPSNUM}/boot/System.map
	ln -s /boot/vmlinuz-${KERNELNAME} ${VPSGLOBPATH}/${VPSNUM}/boot/vmlinuz
	# regen the module dependancies within the chroot (just in case)
	chroot ${VPSGLOBPATH}/${VPSNUM} depmod -a ${KERNELNAME}
fi

# need to install 2.6 compat stuff for centos3
if [ ""$DISTRO = "centos" -a ""$CENTOS_RELEASE="centos3" ]; then
	mkdir -p ${VPSGLOBPATH}/${VPSNUM}/tmp
	wget -O ${VPSGLOBPATH}/${VPSNUM}/tmp/yum.conf.mini ftp://ftp.pasteur.fr/pub/BIS/tru/2.6_CentOS-3/yum.conf.mini
	chroot ${VPSGLOBPATH}/${VPSNUM} yum -c /tmp/yum.conf.mini -y update	
	chroot ${VPSGLOBPATH}/${VPSNUM} yum -c /tmp/yum.conf.mini install initscripts_26
fi

echo "Unmounting proc and filesystem root..."
umount ${VPSGLOBPATH}/${VPSNUM}/proc
umount ${VPSGLOBPATH}/${VPSNUM}

echo "Install script finished"
exit 0
