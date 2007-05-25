#!/bin/sh

# this script will attempt to build a list of RPMs from a mirror
CENTOS_VERSION=centos4
#ARCH=i386
ARCH=x86_64
MIRROR_FILE_LIST=rpmlist.$CENTOS_VERSION
SCRIPT_SOURCE=/usr/lib/rpmstrap/scripts/$CENTOS_VERSION
BASE_FILE_LIST_WN=base.rpm.list.wn
BASE_FILE_LIST=base.rpm.list
STATUS_FILE_LIST=misses.rpm.list
STILL_NOT_FOUND_LIST=stillnotfound.rpm.list
UPDATED_FILE_LIST=updated.rpm.list

# make sure the mirror URL has a / at the end
if [ $CENTOS_VERSION == "centos3" ]; then
MIRROR_URL=ftp://mirror.averse.net/pub/centos/3/os/$ARCH/RedHat/RPMS/
elif [ $CENTOS_VERSION == "centos4" ]; then
MIRROR_URL=ftp://anorien.csc.warwick.ac.uk/CentOS/4/os/x86_64/CentOS/RPMS/
#MIRROR_URL=ftp://mirror.averse.net/pub/centos/4/os/$ARCH/CentOS/RPMS/
#MIRROR_URL=ftp://mirror.centos.org/centos/4/os/x86_64/CentOS/RPMS/
fi

. $SCRIPT_SOURCE

print_rpms_with_numbers() {
    local rpm_list=$(echo "$RPMS" | sed "s/[[:digit:]]\+://")

    echo "RPMs for suite $RPMSUITE and arch $ARCH"
    for a in $rpm_list
    do
        echo " : $a"
    done
}

# regen the base file list from the script
echo -n > $BASE_FILE_LIST_WN
work_out_rpms
for a in $RPMS
do echo $a >> $BASE_FILE_LIST_WN
done

# grab latest file listing
rm .listing index.html*
wget --dont-remove-listing $MIRROR_URL

if [ ! -e .listing ]; then
	echo "$MIRROR_URL is not correct, can't find FTP listing"
	exit 1
fi

# remove useless HTML file
rm index.html
cat .listing | sed -e 's/.* \(.*rpm\).*/\1/' > $MIRROR_FILE_LIST

# first remove the numbers from our base.rpm.list
cat $BASE_FILE_LIST_WN | cut -f2 -d: > $BASE_FILE_LIST

for i in `cat $BASE_FILE_LIST`; do echo -n "$i---" ; grep -c $i $MIRROR_FILE_LIST;done > $STATUS_FILE_LIST

# purge the existing updated file list
echo -n > $UPDATED_FILE_LIST

# since we found all these RPMs, write to the output list
for i in `cat $STATUS_FILE_LIST | grep -- "---[1-9]" | sed 's/---[1-9]//'`; 
do 
	# prepend the order number for this RPM
	base=`echo $i | sed 's/-[^-]*-[^-]*.rpm//'`
	num=`grep ":$i" $BASE_FILE_LIST_WN | cut -f1 -d:`
	echo -n "$num:" >>  $UPDATED_FILE_LIST
	echo $i >> $UPDATED_FILE_LIST
done

echo "Wrote updated file list to $UPDATED_FILE_LIST..."
echo "Still need to find the following RPMs: "`cat $STATUS_FILE_LIST | grep -- "---0" | sed 's/---0//'`

# now go and find the closest match RPM from the mirror
for i in `cat $STATUS_FILE_LIST | grep -- "---0" | sed 's/---0//'`; 
do 
	echo "Looking for $i..."
	base=`echo $i | sed 's/-[^-]*-[^-]*.rpm//'`
	num=`grep ":$i" $BASE_FILE_LIST_WN | cut -f1 -d:`
	echo "Basename is $base..."
	found=`grep -m 1 "^$base.*$ARCH\|^$base.*noarch" $MIRROR_FILE_LIST`
	if [ -n "$found" ]; then
		echo "Found $found"
		echo -n "$num:" >>  $UPDATED_FILE_LIST
		echo $found >> $UPDATED_FILE_LIST
	else
		echo "Couldn't find $base..."
		sleep 1
		echo -n "#$num:" >> $UPDATED_FILE_LIST
		echo "$base NOT FOUND" >> $UPDATED_FILE_LIST
		echo $base >> $STILL_NOT_FOUND_LIST
	fi
done


# finally we need to sort this guy
cat $UPDATED_FILE_LIST | sort -n > $UPDATED_FILE_LIST

# now clean up the files we have used
if [ -e $BASE_FILE_LIST_WN ]; then 
	rm $BASE_FILE_LIST_WN
fi
if [ -e $STATUS_FILE_LIST ]; then
	rm $STATUS_FILE_LIST
fi
if [ -e .listing ]; then
	rm .listing
fi
if [ -e $BASE_FILE_LIST ]; then
	rm $BASE_FILE_LIST
fi

if [ -e $STILL_NOT_FOUND_LIST ]; then
	echo "Still could not find rpm(s) "`cat $STILL_NOT_FOUND_LIST`".  Please check in $MIRROR_FILE_LIST, and update $SCRIPT_SOURCE manually"
else 
	rm $MIRROR_FILE_LIST
fi
if [ -e $STILL_NOT_FOUND_LIST ]; then
	rm $STILL_NOT_FOUND_LIST
fi
echo "Done"
