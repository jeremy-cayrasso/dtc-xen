Summary: SOAP daemon and scripts to allow control panel management for Xen VMs
Name: dtc-xen
Version: 0.4.0
Release: 3
License: GPL
Group: Applications/Internet
Source: ftp://ftp.gplhost.com/debian/pool/lenny/main/d/dtc-xen/dtc-xen_0.3.28.orig.tar.gz

%description
 Dtc-xen is a SOAP server running over HTTPS with authentication, so that a web
 GUI tool can manage, create and destroy domUs under Xen. This package should
 be used in the dom0 of a Xen server. It integrates itself within the DTC web
 hosting control panel.

%prep
%setup
%patch
%build

%install
rm -rf $RPM_BUILD_ROOT

mkdir -p $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT

%clean
rm -rf $RPM_BUILD_ROOT

%files
%changelog
* Sun Mar 21 1999 Cristian Gafton <gafton@redhat.com> 
- auto rebuild in the new build environment (release 3)

%changelog
* Thu, 11 Jun 2009 Thomas Goirand <thomas@goirand.fr>
- Initial release.
