#!/bin/sh

if [ $# -lt 3 ]; then 
	echo "Usage: $0 <xen id> <package id> <ip address> [debian/ubuntu_dapper/centos/gentoo/manual]"
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
LVMNAME=lvm1
VPSGLOBPATH=/xen
#KERNELNAME="2.6.11.12-xenU"
KERNELPATH="/boot/vmlinuz-${KERNELNAME}"
DEBIAN_BINARCH=i386

# Things that most of then time don't change
VPSNUM=$1
VPSNAME=xen${VPSNUM}
VPSHOSTNAME=xen${NODE_NUM}${VPSNUM}
VPSPACK=$2
IPADDR=$3
DISTRO=$4

# default distro to debian
if [ -z $DISTRO ]; then
DISTRO=debian
fi

LVCREATE=/sbin/lvcreate
MKFS=/sbin/mkfs.ext3
MKDIR=/bin/mkdir
MKSWAP=/sbin/mkswap
MOUNT=/bin/mount
DEBOOTSTRAP=/usr/sbin/debootstrap

case "$2" in
	"1")
		VPSHDD=1
		VPSMEM=48
		;;
	"2")
		VPSHDD=3
		VPSMEM=64
		;;
	"3")
		VPSHDD=8
		VPSMEM=128
		;;
	"4")
		VPSHDD=15
		VPSMEM=192
		;;
	"5")
		VPSHDD=25
		VPSMEM=256
		;;
	"6")
		VPSHDD=50
		VPSMEM=384
		;;
	*)
		echo "Cannot find package HDD and MEM conf";
		exit 1
		;;
esac

echo "Seleted ${VPSNAME}: ${VPSHDD}G HDD and ${VPSMEM}MB RAM";
echo "Creating disks..."

if [ ! -L /dev/${LVMNAME}/${VPSNAME} ] ; then
	$LVCREATE -L${VPSHDD}G -n${VPSNAME} ${LVMNAME}
	$MKFS /dev/${LVMNAME}/${VPSNAME}
	$MKDIR -p ${VPSGLOBPATH}/${VPSNUM}
fi
if [ ! -L /dev/${LVMNAME}/${VPSNAME}swap ] ; then
	$LVCREATE -L${VPSMEM} -n${VPSNAME}swap ${LVMNAME}
	$MKSWAP /dev/${LVMNAME}/${VPSNAME}swap
fi
if grep ${VPSNAME} /etc/fstab >/dev/null ; then
	echo "LV already exists in fstab"
else
	echo "/dev/mapper/${LVMNAME}-${VPSNAME}  ${VPSGLOBPATH}/${VPSNUM} ext3    defaults,noauto 0 0" >>/etc/fstab
fi
echo "Mouting..."
$MOUNT ${VPSGLOBPATH}/${VPSNUM}

echo "Bootstraping..."
if [ ""$DISTRO = "centos" ] ; then
	if [ ! -e /usr/src/centos3 ] ; then
		echo "Please install CentOS 3 rpms in /usr/src"
		echo "This can be done using: rpmstrap --verbose --download-only centos3 /usr/src/centos3"
		exit
	fi
	if [ ! -e /usr/bin/rpmstrap ] ; then
		echo "Please install rpmstrap from http://rpmstrap.pimpscript.net/"
		exit
	fi
	/usr/bin/rpmstrap --verbose --local-source /usr/src/centos3 centos3 ${VPSGLOBPATH}/${VPSNUM}
elif [ ""$DISTRO = "debian" ] ; then
	$DEBOOTSTRAP --arch ${DEBIAN_BINARCH} sarge ${VPSGLOBPATH}/${VPSNUM} ${DEBIAN_REPOS}
elif [ ""$DISTRO = "ubuntu_dapper" ] ; then
	$DEBOOTSTRAP --arch i386 dapper ${VPSGLOBPATH}/${VPSNUM} http://archive.ubuntu.ocm/ubuntu
elif [ ""$DISTRO = "gentoo" ]; then
	if [ ! -e /usr/src/gentoo/stage3-x86-2006.0.tar.bz2 ]; then
		echo "Please download the gentoo stage3 from http://mirror.gentoo.gr.jp/releases/x86/2006.0/stages/stage3-x86-2006.0.tar.bz2"
		echo "Or another gentoo mirror"
		exit 
	fi
	tar -xvjpf /usr/src/gentoo/stage3-x86-2006.0.tar.bz2 -C ${VPSGLOBPATH}/${VPSNUM}
	# grab the latest portage
	pushd /usr/src/gentoo
	wget -N http://mirror.gentoo.gr.jp/snapshots/portage-latest.tar.bz2.md5sum
	wget -N http://mirror.gentoo.gr.jp/snapshots/portage-latest.tar.bz2
	md5sum -c portage-latest.tar.bz2.md5sum
	tar -xvjpf portage-latest.tar.bz2 -C ${VPSGLOBPATH}/${VPSNUM}/usr/
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
${IPADDR}	${VPSHOSTNAME} dtc.${VPSHOSTNAME}.gplhost.com ${VPSHOSTNAME}.gplhost.com

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

# handle the network setup
if [ ""$DISTRO = "centos" ] ; then
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
	# Make the console device
	/dev/MAKEDEV ${VPSGLOBPATH}/${VPSNUM}/dev/console
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
" >${VPSGLOBPATH}/${VPSNUM}/etc/apt
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

echo "kernel = \"${KERNELPATH}\"
memory = ${VPSMEM}
name = \"${VPSNAME}\"
#cpu = -1   # leave to Xen to pick
nics=1
#vif = [ 'mac=aa:00:00:00:00:11, bridge=xen-br0' ]
disk = [ 'phy:/dev/mapper/lvm1-xen${VPSNUM},sda1,w','phy:/dev/mapper/lvm1-xen${VPSNUM}swap,sda2,w' ]
root = \"/dev/sda1 ro\"
# Sets runlevel 4.
extra = \"4\"
" >/etc/xen/${VPSNAME}
ln -s ../${VPSNAME} /etc/xen/auto/${VPSNAME}

echo "Copying modules..."
mv ${VPSGLOBPATH}/${VPSNUM}/lib/tls ${VPSGLOBPATH}/${VPSNUM}/lib/tls.disabled
# create the /lib/modules if it doesn't exist
if [ ! -e ${VPSGLOBPATH}/${VPSNUM}/lib/modules ]; then 
	mkdir -p ${VPSGLOBPATH}/${VPSNUM}/lib/modules
fi
cp -auxvf /lib/modules/${KERNELNAME} ${VPSGLOBPATH}/${VPSNUM}/lib/modules
cp -L ${KERNELPATH} ${VPSGLOBPATH}/${VPSNUM}/boot
cp -L /boot/System.map-${KERNELNAME} ${VPSGLOBPATH}/${VPSNUM}/boot
# symlink the System.map and kernel
ln -s /boot/System.map-${KERNELNAME} ${VPSGLOBPATH}/${VPSNUM}/boot/System.map
ln -s /boot/vmlinuz-${KERNELNAME} ${VPSGLOBPATH}/${VPSNUM}/boot/vmlinuz
# regen the module dependancies within the chroot (just in case)
chroot ${VPSGLOBPATH}/${VPSNUM} depmod -a ${KERNELNAME}
echo "Unmounting..."
umount ${VPSGLOBPATH}/${VPSNUM}
