#!/bin/bash

CACHEDIR="/var/cache/yum"      # where yum caches stuff -- is created as a subdir
                               # of the destination chroot

# FIXME perhaps after installation the script can modify the target machine's yum config to point to our Squid proxy
#       or define http_proxy inside the machine.  that would make upgrades for customers much much faster.
# FIXME once that is done, we can stop using apt-proxy or apt-cacher

YUMENVIRON="$1"                # where the yum config is generated and deployed
INSTALLROOT="$2"               # destination directory / chroot for installation

if [ "$INSTALLROOT" == "" -o ! -d "$INSTALLROOT" -o "$YUMENVIRON" == "" ] ; then
	echo "usage: centos-installer /yum/environment (will be created) /destination/directory (must exist)"
	echo "dest dir MUST BE an absolute path"
	exit 126
fi

set -e
set -x

# detect architecture
ARCH=`uname -m`
if [ "$ARCH" == x86_64 ] ; then
	exclude="*.i386 *.i586 *.i686"
	distroarch=x86_64
elif [ "$ARCH" == i686 ] ; then
	exclude="*.x86_64"
	distroarch=i386
else
	echo "Unknown architecture: $ARCH -- stopping centos-installer"
	exit 3
fi

# make yum environment

mkdir -p "$YUMENVIRON"/{pluginconf.d,repos.d} "$CACHEDIR" "$INSTALLROOT/var/log"

# configure yum:

cat > "$YUMENVIRON/yum.conf" << EOF
[main]
reposdir=$YUMENVIRON/repos.d
pluginconfpath=$YUMENVIRON/pluginconf.d
cachedir=$CACHEDIR
installroot=$INSTALLROOT
exclude=$exclude
keepcache=1
debuglevel=2
pkgpolicy=newest
distroverpkg=centos-release
tolerant=1
exactarch=1
obsoletes=1
gpgcheck=1
plugins=1
metadata_expire=1800
EOF

# FIXME: add mirrorlist argument below.  make yum more robust.

cat > "$YUMENVIRON/pluginconf.d/installonlyn.conf" << EOF
[main]
enabled=1
tokeep=5
EOF

cat > "$YUMENVIRON/repos.d/CentOS-Base.repo" << EOF
[base]
name=CentOS-5 - Base
baseurl=http://mirror.centos.org/centos/5/os/$distroarch/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5

[updates]
name=CentOS-5 - Updates
baseurl=http://mirror.centos.org/centos/5/updates/$distroarch/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5

[addons]
name=CentOS-5 - Addons
baseurl=http://mirror.centos.org/centos/5/addons/$distroarch/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5

[extras]
name=CentOS-5 - Extras
baseurl=http://mirror.centos.org/centos/5/extras/$distroarch/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5

[centosplus]
name=CentOS-5 - Plus
baseurl=http://mirror.centos.org/centos/5/centosplus/$distroarch/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5
EOF

# unleash yum

yum -c "$YUMENVIRON/yum.conf" -y install basesystem centos-release yum