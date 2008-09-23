#!/bin/sh

set -e

USAGE="Usage: $0 <xen id> <ram size> <allipaddrs> <vncpassword> <howtoboot>
Where allipaddrs is of the form '1.2.3.4 1.2.3.5' (eg: separated by space),
and howtoboot is 'name.iso' in /var/lib/dtc-xen/ttyssh_home/xenXX or 'hdd'"
if [ $# -lt 5 ]; then 
	echo $USAGE
fi

# Source the configuration in the config file!
. /etc/dtc-xen/dtc_create_vps.conf.sh

if [ "$LVMNAME" = "" ] ; then LVMNAME=lvm1 ; fi
VPSGLOBPATH=${VPS_MOUNTPOINT}
INSTALL_KERNELPATH="/boot/netbsd-INSTALL_XENU"
NORMAL_KERNELPATH="/boot/netbsd-XENU"

# Get parameters from command line
VPSNUM=$1
VPSNAME=xen${VPSNUM}
VPSHOSTNAME=xen${NODE_NUM}${VPSNUM}
RAMSIZE=$2
ALL_IPADDRS=$3
VNC_PASSWORD=$4
HOW_TO_BOOT=$5

calcMacAddr () {
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

echo -n "kernel = \"/usr/lib/xen/boot/hvmloader\"
builder = 'hvm'
memory = ${RAMSIZE}
name = \"${VPSNAME}\"
vif = [ 'type=ioemu, mac=${MAC_ADDR}, ip=${ALL_IPADDRS}' ]
disk=[ 'phy:/dev/mapper/${LVMNAME}-xen${VPSNUM},ioemu:hda,w'" >/etc/xen/${VPSNAME}
# Set the additional cdrom drives: add all *.iso files to the config file
HDDLIST="bcdefghijklmnopqrstuvwxyz"
INCREMENT=2
for i in `find /var/lib/dtc-xen/ttyssh_home/xen${VPSNUM}/ -mindepth 1 -maxdepth 1 -iname '*.iso' | cut -d'/' -f7 | tr \\\r\\\n ,\ ` ; do
	DRIVE_LETTER=`echo ${HDDLIST} | awk '{print substr($0,'${INCREMENT}',1)}'`
	INCREMENT=$(( $INCREMENT + 1))
	echo -n ,\'file:/var/lib/dtc-xen/ttyssh_home/xen${VPSNUM}/$i,hd${DRIVE_LETTER}:cdrom,r\' >>/etc/xen/${VPSNAME}
done
echo " ]" >>/etc/xen/${VPSNAME}

# Set the VNC configuration
if [ -z "${VNC_PASSWORD}" -o "${VNC_PASSWORD}" = "none" ] ; then
	echo "nographic=1
vnc=0" >>/etc/xen/${VPSNAME}
else
	echo "vfb = [ \"type=vnc,vncdisplay=21,vncpasswd=${VNC_PASSWORD}\" ]
nographic=0
vnc=1
stdvga=1" >>/etc/xen/${VPSNAME}
fi

# Set the boot device
if [ ! "${HOW_TO_BOOT}" = "hdd" -a -e /var/lib/dtc-xen/ttyssh_home/xen${VPSNUM}/${HOW_TO_BOOT} ] ; then
	echo "cdrom=\"/var/lib/dtc-xen/ttyssh_home/xen${VPSNUM}/${HOW_TO_BOOT}\"
boot=\"d\"" >>/etc/xen/${VPSNAME}
else
	echo "boot=\"c\"
nographic=1" >>/etc/xen/${VPSNAME}
fi
echo "serial='pty'" >>/etc/xen/${VPSNAME}
