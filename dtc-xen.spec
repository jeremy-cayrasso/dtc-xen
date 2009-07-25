Name: dtc-xen
Summary: DTC Xen VPS remote management suite
Version: 0.5.0
Release: 7

Group: System Environment/Daemons

License: GPLv2+
Url: http://www.gplhost.com/software-dtc-xen.html
Source: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

Requires: python
Requires: logrotate
Requires: python-soap
Requires: xen
Requires: openssl
Requires: chkconfig
Requires: coreutils
Requires: shadow-utils
Requires: sudo
Requires: gawk
Requires: lvm2
# for the htpasswd command:
Requires: httpd
Requires: yum
Requires: debootstrap
BuildRequires: make
BuildRequires: coreutils
BuildRequires: gzip
BuildRequires: sed

BuildArch: noarch

%description
DTC-Xen lets you create and manage Xen VPS instances remotely, monitor 
their status and shut them down.  You can use any SOAP client to
interface with DTC-Xen, but you might want to use DTC to easily
manage an entire farm of Xen VPSes.

%package firewall
Summary: DTC Xen VPS firewall
Group: Applications/System
Requires: iptables
%description firewall
DTC-Xen firewall is a rate-limiting firewall script that you can use on your
servers using DTC-Xen.

If running in a production environment, you might want to have a basic
firewall running on your dom0 to avoid having DoS attack. This is not the
state-of-the-art, but just another attempt to make things a bit more smooth.
Comments and contribution are more than welcome!
 
The main principle of this firewall script is to rate limit connections to
both your dom0 and your VPSes. It's principle is NOT block any connection. For
example, dtc-xen-firewall denies ssh for 300 seconds after 10 attempts on your
dom0, rate limit ping to 5 per seconds on your dom0 and to 50/s globally for
all your VPS, and does the same kind of thing for SYN flood attacks. Take
care, it also blocks any connection to the port 25, as in a normal dom0, you
would install a mail server to send system messages to the administrators, but
you don't want to accept any incoming message.


%prep
rm -rf %{buildroot}/*
%setup -q -n %{name}

%build

%install

set -e

make install DESTDIR=%{buildroot} DISTRO=centos SYSCONFIG_DIR=%{_sysconfdir} USRSBIN_DIR=%{_sbindir} USRBIN_DIR=%{_bindir} INITRD_DIR=%{_initrddir} \
	MAN_DIR=%{_mandir} SHARE_DIR=%{_datadir} VARLIB_DIR=%{_localstatedir}/lib SHARE_DOC_DIR=%{_defaultdocdir} USRBIN_DIR=%{_bindir}

sed -i 's/root adm/root root/g' %{buildroot}%{_sysconfdir}/logrotate.d/dtc-xen
sed -i 's|^provisioning_mount_point.*|provisioning_mount_point=%{_localstatedir}/lib/dtc-xen/mnt|g' %{buildroot}%{_sysconfdir}/dtc-xen/dtc-xen.conf
touch %{buildroot}%{_sysconfdir}/dtc-xen/htpasswd
chmod 600 %{buildroot}%{_sysconfdir}/dtc-xen/htpasswd
sed -i 's|/etc/dtc-xen|%{_sysconfdir}/dtc-xen|g' %{buildroot}%{_sbindir}/dtc-xen-volgroup

make install_dtc-xen-firewall DISTRO=centos DESTDIR=%{buildroot} DISTRO=centos SYSCONFIG_DIR=%{_sysconfdir} USRSBIN_DIR=%{_sbindir} \
	INITRD_DIR=%{_initrddir} MAN_DIR=%{_mandir} SHARE_DIR=%{_datadir} VARLIB_DIR=%{_localstatedir}/lib \
	SHARE_DOC_DIR=%{_defaultdocdir} USRBIN_DIR=%{_bindir}


%clean
rm -rf %{buildroot}

%pre
/usr/sbin/groupadd -r xenusers 2>/dev/null
exit 0


%post
oldumask=`umask`
umask 077

if [ ! -f %{_sysconfdir}/pki/tls/private/dtc-xen.key ] ; then
/usr/bin/openssl genrsa -rand /proc/apm:/proc/cpuinfo:/proc/dma:/proc/filesystems:/proc/interrupts:/proc/ioports:/proc/pci:/proc/rtc:/proc/uptime 1024 > %{_sysconfdir}/pki/tls/private/dtc-xen.key 2> /dev/null
fi

FQDN=`hostname`
if [ "x${FQDN}" = "x" ]; then
   FQDN=localhost.localdomain
fi

if [ ! -f %{_sysconfdir}/pki/tls/certs/dtc-xen.crt ] ; then
cat << EOF | /usr/bin/openssl req -new -key %{_sysconfdir}/pki/tls/private/dtc-xen.key \
         -x509 -days 365 -set_serial $RANDOM \
         -out %{_sysconfdir}/pki/tls/certs/dtc-xen.crt 2>/dev/null
--
SomeState
SomeCity
SomeOrganization
SomeOrganizationalUnit
${FQDN}
root@${FQDN}
EOF
fi

umask $oldumask

if [ "$1" == "1" ] ; then
# Manuel: this below will setup MULTIPLE TIMES dtc-xen_userconsole in /etc/shells
# if we also install multiple times the package. Please fix!!!
	echo "%{_bindir}/dtc-xen_userconsole" >> %{_sysconfdir}/shells
# same here, please do a grep as test first
	[ -f %{_sysconfdir}/sudoers ] && echo "%xenusers       ALL= NOPASSWD: /usr/sbin/xm console xen*" >> %{_sysconfdir}/sudoers
	/sbin/chkconfig --add dtc-xen
	if [ -x /sbin/runlevel -a -x /sbin/service -a -x /bin/awk ] ; then
		runlevel=` /sbin/runlevel | awk ' { print $2 } ' `
		if [ $runlevel == 3 -o $runlevel == 4 -o $runlevel == 4 ] ; then
			/sbin/service dtc-xen start
		fi
	fi
else
	if [ -x /sbin/service ] ; then
		/sbin/service dtc-xen condrestart
	fi
fi

exit 0

%preun
if [ "$1" == "0" ] ; then
	if [ -x /sbin/service ] ; then /sbin/service dtc-xen stop ; fi
	/sbin/chkconfig --del dtc-xen
	without=`grep -v 'dtc-xen_userconsole' %{_sysconfdir}/shells`
	echo "$without" > %{_sysconfdir}/shells
	[ -f %{_sysconfdir}/sudoers ] && {
		without=`grep -v '%xenusers' %{_sysconfdir}/sudoers` 
		echo "$without" > %{_sysconfdir}/sudoers
	}
fi


%postun
# Manuel: are you 100% sure you should delete the group? That
# seems a bad idea to me, as when reinstalling, it could change
# the GID of some already existing files. Know what I mean???
if [ "$1" == "0" ] ; then
	/usr/sbin/groupdel xenusers
fi


%post firewall
if [ "$1" == "1" ] ; then
	
	/sbin/chkconfig --add dtc-xen-firewall
	if [ -x /sbin/runlevel -a -x /sbin/service -a -x /bin/awk ] ; then
		runlevel=` /sbin/runlevel | awk ' { print $2 } ' `
		if [ $runlevel == 3 -o $runlevel == 4 -o $runlevel == 4 ] ; then
			/sbin/service dtc-xen-firewall start
		fi
	fi
else
	if [ -x /sbin/service ] ; then
		/sbin/service dtc-xen-firewall condrestart
	fi
fi

%preun firewall
if [ "$1" == "0" ] ; then
	if [ -x /sbin/service ] ; then
		/sbin/service dtc-xen-firewall stop
	fi
	/sbin/chkconfig --del dtc-xen-firewall
fi


%files
%defattr(0755,root,root,-)
%doc doc/changelog doc/README.RPM doc/examples/*
%{_sbindir}/*
%{_bindir}/*
%dir %{_sysconfdir}/dtc-xen
%config(noreplace) %{_sysconfdir}/dtc-xen/bashrc
%config(noreplace) %{_sysconfdir}/dtc-xen/motd
%config(noreplace) %{_sysconfdir}/dtc-xen/sources.list
%config(noreplace) %{_sysconfdir}/dtc-xen/inittab
%attr(0600,root,root) %config(noreplace) %{_sysconfdir}/dtc-xen/dtc-xen.conf
%attr(0600,root,root) %config(noreplace) %{_sysconfdir}/dtc-xen/htpasswd
%config(noreplace) %{_sysconfdir}/logrotate.d/*
%config %{_initrddir}/dtc-xen
%dir %{_localstatedir}/lib/dtc-xen
%attr(0750,root,root) %{_localstatedir}/lib/dtc-xen/states
%attr(0750,root,root) %{_localstatedir}/lib/dtc-xen/perfdata
%attr(0750,root,root) %{_localstatedir}/lib/dtc-xen/mnt
%attr(0755,root,root) %{_localstatedir}/lib/dtc-xen/ttyssh_home
%{_datadir}/dtc-xen/*
%{_mandir}/*/*

%files firewall
%config(noreplace) %{_sysconfdir}/dtc-xen/dtc-xen-firewall-config
%config %{_initrddir}/dtc-xen-firewall

%changelog
* Wed Jun 24 2009 Manuel Amador (Rudd-O) <rudd-o@rudd-o.com> 0.4.0-7
- added debootstrap dependency

* Fri Jun 11 2009 Manuel Amador (Rudd-O) <rudd-o@rudd-o.com> 0.4.0-1
- initial release
