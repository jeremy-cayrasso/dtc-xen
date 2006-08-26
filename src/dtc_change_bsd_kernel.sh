#!/bin/sh

USAGE="Usage: $0 <xen id> <ram size> [normal|install]"
if [ $# -lt 3 ]; then 
	echo $USAGE
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
INSTALL_KERNELPATH="/boot/netbsd-INSTALL_XENU"
NORMAL_KERNELPATH="/boot/netbsd-XENU"
#DEBIAN_BINARCH=i386

# Things that most of then time don't change
VPSNUM=$1
VPSNAME=${VPSNUM}
VPSHOSTNAME=xen${NODE_NUM}${VPSNUM}
RAMSIZE=$2
KERNEL_TYPE=$3

case "$KERNEL_TYPE" in
	"install")
		KERNELPATH=$INSTALL_KERNELPATH
		;;
	"normal")
		KERNELPATH=$NORMAL_KERNELPATH
		;;
	*)
		echo $USAGE;
		exit 1
		;;
esac
	

echo "kernel = \"${KERNELPATH}\"
memory = ${RAMSIZE}
name = \"${VPSNAME}\"
#cpu = -1   # leave to Xen to pick
nics=1
#vif = [ 'mac=aa:00:00:00:00:11, bridge=xen-br0' ]
disk = [ 'phy:/dev/mapper/lvm1-${VPSNAME},0x3,w' ]
" >/etc/xen/${VPSNAME}
if [ ! -e /etc/xen/auto/${VPSNAME} ] ; then
	ln -s ../${VPSNAME} /etc/xen/auto/${VPSNAME}
fi
