#!/bin/bash

CACHEDIR="/var/cache/yum"      # where yum caches stuff -- is created as a subdir
                               # of the destination chroot

# FIXME perhaps after installation the script can modify the target machine's yum config to point to our Squid proxy
#       or define http_proxy inside the machine.  that would make upgrades for customers much much faster.
# better idea: instead of using a web cache, use a stash on the machine, we rsync the new RPMs into it once it's finished
# we would need a mutex (flock or fcntl based?) that mutially excludes the critical section
# the critical section is both the yum and the rsync process
# we also need to rsync packages from the stash into the var cache on the vps, and a mutex to lock out if another yum is running, just as in the first scenario
# cannot use a symlink because its chrooted for the duration of the process
# at any case, the repo names for different distros need to be different, otherwise the caches will clash horribly
# FIXME once that is done, we can stop using apt-proxy or apt-cacher
# FIXME try to make it for suse, mandriva or any other rpm-based distro

YUMENVIRON="$1"                # where the yum config is generated and deployed
INSTALLROOT="$2"               # destination directory / chroot for installation

if [ "$INSTALLROOT" == "" -o ! -d "$INSTALLROOT" -o "$YUMENVIRON" == "" ] ; then
	echo "usage: centos-installer /yum/environment (will be created) /destination/directory (must exist)"
	echo "dest dir MUST BE an absolute path"
	exit 126
fi

set -e
set -x

which rpm >/dev/null 2>&1 || { echo "rpm is not installed.  please install rpm." ; exit 124 ; }

# sometimes when the RPM database is inconsistent, yum fails but exits with success status
# we make sure the db is in good health
rpm --rebuilddb

# set distro ver
releasever=5

# detect architecture
ARCH=`uname -m`
if [ "$ARCH" == x86_64 ] ; then
	exclude="*.i386 *.i586 *.i686"
	basearch=x86_64
elif [ "$ARCH" == i686 ] ; then
	exclude="*.x86_64"
	basearch=i386
else
	echo "Unknown architecture: $ARCH -- stopping centos-installer"
	exit 3
fi

# make yum environment

mkdir -p "$YUMENVIRON"/{pluginconf.d,repos.d} "$CACHEDIR" "$INSTALLROOT/var/log"

# In case the folder is not there:
mkdir -p /var/lib/rpm

# configure yum:

cat > "$YUMENVIRON/yum.conf" << EOF
[main]
reposdir=$YUMENVIRON/repos.d
pluginconfpath=$YUMENVIRON/pluginconf.d
cachedir=$CACHEDIR
installroot=$INSTALLROOT
exclude=$exclude
keepcache=1
#debuglevel=4
#errorlevel=4
pkgpolicy=newest
distroverpkg=centos-release
tolerant=1
exactarch=1
obsoletes=1
gpgcheck=1
plugins=1
metadata_expire=1800
EOF

cat > "$YUMENVIRON/pluginconf.d/installonlyn.conf" << EOF
[main]
enabled=1
tokeep=5
EOF

cat > "$YUMENVIRON/repos.d/CentOS-Base.repo" << EOF
[base]
name=CentOS-5 - Base
#baseurl=http://mirror.centos.org/centos/$releasever/os/$basearch/
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5

[updates]
name=CentOS-5 - Updates
#baseurl=http://mirror.centos.org/centos/$releasever/updates/$basearch/
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=updates
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5

[addons]
name=CentOS-5 - Addons
#baseurl=http://mirror.centos.org/centos/$releasever/addons/$basearch/
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=addons
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5

[extras]
name=CentOS-5 - Extras
#baseurl=http://mirror.centos.org/centos/$releasever/extras/$basearch/
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5

[centosplus]
name=CentOS-5 - Plus
#baseurl=http://mirror.centos.org/centos/$releasever/centosplus/$basearch/
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=centosplus
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5
EOF

# unleash yum

export LANG=C
exec yum -c "$YUMENVIRON/yum.conf" -y install basesystem centos-release yum
