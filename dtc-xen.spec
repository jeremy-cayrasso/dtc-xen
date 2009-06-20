Name: dtc-xen
Summary: DTC Xen VPS remote management suite
Version: 0.0.1
Release: 1

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
# for the htpasswd command:
Requires: httpd
BuildRequires: coreutils
BuildRequires: gzip
BuildRequires: sed

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

mkdir -p %{buildroot}%{_sbindir} %{buildroot}%{_bindir} %{buildroot}%{_localstatedir}/lib/%{name}/{perfdata,states,mnt}
mkdir -p %{buildroot}%{_mandir}/{1,8}
mkdir -p %{buildroot}%{_datadir}/%{name}
mkdir -p %{buildroot}%{_sysconfdir}/{%{name},logrotate.d}
mkdir -p %{buildroot}%{_initrddir}

cp src/dtc* src/xm* src/vg* %{buildroot}%{_sbindir}
chmod 755 %{buildroot}%{_sbindir}/*
mv %{buildroot}%{_sbindir}/*userconsole* %{buildroot}%{_bindir}
sed -i 's|/etc/dtc-xen|%{_sysconfdir}/%{name}|g' %{buildroot}%{_sbindir}/dtc-xen-volgroup


cp src/{motd,soap.conf,bashrc} etc/dtc-xen/* %{buildroot}%{_sysconfdir}/%{name}
mv %{buildroot}%{_sysconfdir}/%{name}/soap.conf %{buildroot}%{_sysconfdir}/%{name}/dtc-xen.conf 
sed -i 's/soap_server_host.*/listen_address=0.0.0.0/g' %{buildroot}%{_sysconfdir}/%{name}/dtc-xen.conf
sed -i 's/soap_server_port=8089/listen_port=8089/g' %{buildroot}%{_sysconfdir}/%{name}/dtc-xen.conf
echo 'admin_user=dtc-xen' >> %{buildroot}%{_sysconfdir}/%{name}/dtc-xen.conf
echo '# cert_passphrase is to be used if the certificate you created has a passphrase' >> %{buildroot}%{_sysconfdir}/%{name}/dtc-xen.conf
echo '#cert_passphrase=' >> %{buildroot}%{_sysconfdir}/%{name}/dtc-xen.conf
echo '# provisioning_volgroup lets you choose which volume group to provision disk space from -- if left empty, it picks the first one on your system' >> %{buildroot}%{_sysconfdir}/%{name}/dtc-xen.conf
echo '#provisioning_volgroup=' >> %{buildroot}%{_sysconfdir}/%{name}/dtc-xen.conf
echo 'provisioning_mount_point=%{_localstatedir}/lib/%{name}/mnt' >> %{buildroot}%{_sysconfdir}/%{name}/dtc-xen.conf
chmod 644 %{buildroot}%{_sysconfdir}/%{name}/*
touch %{buildroot}%{_sysconfdir}/%{name}/htpasswd
chmod 600 %{buildroot}%{_sysconfdir}/%{name}/*

cp etc/logrotate.d/dtc-xen %{buildroot}%{_sysconfdir}/logrotate.d
sed -i 's/root adm/root root/g' %{buildroot}%{_sysconfdir}/logrotate.d/dtc-xen
chmod 644 %{buildroot}%{_sysconfdir}/logrotate.d/*

cp etc/init.d/dtc-xen.rh %{buildroot}%{_initrddir}/dtc-xen
cp etc/init.d/dtc-xen-firewall.rh %{buildroot}%{_initrddir}/dtc-xen-firewall
chmod 755 %{buildroot}%{_initrddir}/*

cp src/Properties.py 3rdparty/daemon.py %{buildroot}%{_datadir}/%{name}
chmod 644 %{buildroot}%{_datadir}/%{name}/*

cp doc/*1 %{buildroot}%{_mandir}/1
cp doc/*8 %{buildroot}%{_mandir}/8
for a in  %{buildroot}%{_mandir}/*/* ; do gzip $a ; done
chmod 644 %{buildroot}%{_mandir}/*/*

true

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
	echo "%{_bindir}/dtc-xen_userconsole" >> %{_sysconfdir}/shells
	[ -f %{_sysconfdir}/sudoers ] && echo "%xenusers       ALL= NOPASSWD: /usr/sbin/xm console xen*" >> %{_sysconfdir}/sudoers
	/sbin/chkconfig --add %{name}
	if [ -x /sbin/runlevel -a -x /sbin/service -a -x /bin/awk ] ; then
		runlevel=` /sbin/runlevel | awk ' { print $2 } ' `
		if [ $runlevel == 3 -o $runlevel == 4 -o $runlevel == 4 ] ; then
			/sbin/service %{name} start
		fi
	fi
else
	if [ -x /sbin/service ] ; then
		/sbin/service %{name} condrestart
	fi
fi

exit 0


%preun
if [ "$1" == "0" ] ; then
	if [ -x /sbin/service ] ; then /sbin/service %{name} stop ; fi
	/sbin/chkconfig --del %{name}
	without=`grep -v 'dtc-xen_userconsole' %{_sysconfdir}/shells`
	echo "$without" > %{_sysconfdir}/shells
	[ -f %{_sysconfdir}/sudoers ] && {
		without=`grep -v '%xenusers' %{_sysconfdir}/sudoers` 
		echo "$without" > %{_sysconfdir}/sudoers
	}
fi


%postun
if [ "$1" == "0" ] ; then
	/usr/sbin/groupdel xenusers
fi


%post firewall
if [ "$1" == "1" ] ; then
	
	/sbin/chkconfig --add %{name}-firewall
	if [ -x /sbin/runlevel -a -x /sbin/service -a -x /bin/awk ] ; then
		runlevel=` /sbin/runlevel | awk ' { print $2 } ' `
		if [ $runlevel == 3 -o $runlevel == 4 -o $runlevel == 4 ] ; then
			/sbin/service %{name}-firewall start
		fi
	fi
else
	if [ -x /sbin/service ] ; then
		/sbin/service %{name}-firewall condrestart
	fi
fi

%preun firewall
if [ "$1" == "0" ] ; then
	if [ -x /sbin/service ] ; then
		/sbin/service %{name}-firewall stop
	fi
	/sbin/chkconfig --del %{name}-firewall
fi


%files
%defattr(0755,root,root,-)
%doc doc/changelog doc/README.RPM doc/examples/* src/soap_client.py
%{_sbindir}/*
%attr(0755,root,xenusers) %{_bindir}/*
%dir %{_sysconfdir}/%{name}
%config(noreplace) %{_sysconfdir}/%{name}/bashrc
%config(noreplace) %{_sysconfdir}/%{name}/motd
%attr(0600,root,root) %config(noreplace) %{_sysconfdir}/%{name}/dtc-xen.conf
%attr(0600,root,root) %config(noreplace) %{_sysconfdir}/%{name}/htpasswd
%config(noreplace) %{_sysconfdir}/logrotate.d/*
%config %{_initrddir}/%{name}
%dir %{_localstatedir}/lib/%{name}
%attr(0750,root,root) %{_localstatedir}/lib/%{name}/states
%attr(0750,root,root) %{_localstatedir}/lib/%{name}/perfdata
%attr(0750,root,root) %{_localstatedir}/lib/%{name}/mnt
%{_datadir}/%{name}/*
%{_mandir}/*/*

%files firewall
%config(noreplace) %{_sysconfdir}/%{name}/dtc-xen-firewall-config
%config %{_initrddir}/%{name}-firewall

%changelog
* Fri Jun 11 2009 Manuel Amador (Rudd-O) <rudd-o@rudd-o.com> 0.0.1-1
- initial release
