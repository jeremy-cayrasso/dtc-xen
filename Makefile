#!/usr/bin/make -f

# Set to something else if you want to install elsewhere than /
# DESTDIR=""

# Set DISTRO=centos if you want to build for CentOS or other
# RPM based distributions

# Some default values that can be overrided
SHARE_DIR?=/usr/share
VARLIB_DIR?=/var/lib
SYSCONFIG_DIR?=/etc
SHARE_DOC_DIR?=/usr/share/doc
MAN_DIR?=/usr/share/man
USRSBIN_DIR?=/usr/sbin
USRBIN_DIR?=/usr/bin
INITRD_DIR?=/etc/init.d
SHARE_DIR?=/usr/share

INSTALL?=install -D
INSTALL_DIR?=install -d

DISTRO?=debian

MAN8_PAGES=vgdisplay_free_size.8 dtc-soap-server.8 xm_info_free_memory.8 dtc_change_bsd_kernel.8 dtc_reinstall_os.8 \
dtc_setup_vps_disk.8 dtc-xen_finish_install.8 dtc_install_centos.8 dtc_kill_vps_disk.8 dtc_write_xenpv_conf.8 \
dtc-xen_domUconf_network_debian.8 dtc-xen_domUconf_network_redhat.8 dtc-xen_domUconf_standard.8 dtc-xen-volgroup.8 \
dtc-xen-client.8

SBIN_SH_SCRIPTS=dtc_kill_vps_disk xm_info_free_memory vgdisplay_free_size dtc_setup_vps_disk dtc_reinstall_os \
dtc_change_bsd_kernel dtc_write_xenpv_conf dtc_install_centos dtc-xen_domUconf_standard dtc-xen_domUconf_network_debian \
dtc-xen_domUconf_network_redhat dtc-xen_finish_install dtc-soap-server dtc-xen-volgroup dtc-xen_domU_gen_xen_conf

BIN_SH_SCRIPTS=dtc-xen-client

VARLIB_FOLDERS=states perfdata mnt

THIRD_PARTY=daemon.py Properties.py

default:
	@-echo "Building... not..."

clean:	
	rm $(DESTDIR)$(USRSBIN_DIR)/dtc-soap-server
	for i in $(THIRD_PARTY) ; do rm $(DESTDIR)$(SHARE_DIR)/dtc-xen/$$i ; done

	rm $(DESTDIR)$(USRSBIN_DIR)/dtc-xen_finish_install

# The utilities used by the soap server
	rm $(DESTDIR)/usr/bin/dtc-xen_userconsole
	for i in $(SBIN_SH_SCRIPTS) ; do rm $(DESTDIR)$(USRSBIN_DIR)/$$i ; done
	for i in $(BIN_SH_SCRIPTS) ; do rm $(DESTDIR)$(USRBIN_DIR)/$$i ; done

# DTC autodeploy script
	rm $(DESTDIR)$(SHARE_DIR)/dtc-xen/dtc-panel_autodeploy.sh
	rm $(DESTDIR)$(SHARE_DIR)/dtc-xen/selection_config_file

# man pages
	for i in $(MAN8_PAGES) ; do rm $(DESTDIR)$(MAN_DIR)/man8/$$i.gz ; done
	rm $(DESTDIR)$(MAN_DIR)/man1/dtc-xen_userconsole.1.gz

install_dtc-xen-firewall:
	$(INSTALL) -m 0640 etc/dtc-xen/dtc-xen-firewall-config $(DESTDIR)$(SYSCONFIG_DIR)/dtc-xen/dtc-xen-firewall-config
	if [ ! $(DISTRO) = "debian" ] ; then \
		$(INSTALL) -m 0755 etc/init.d/dtc-xen-firewall.rh $(DESTDIR)$(INITRD_DIR)/dtc-xen-firewall ; fi

install:
# Sysconfig stuffs
	$(INSTALL) -m 0644 etc/logrotate.d/dtc-xen $(DESTDIR)$(SYSCONFIG_DIR)/logrotate.d/dtc-xen
	# We do a cp for debian, so it will be used by dh_installinit in debian/rules, so we don't really care about the Unix rights
	if [ ! $(DISTRO) = "debian" ] ; then \
		$(INSTALL) -m 0755 etc/init.d/dtc-xen.rh $(DESTDIR)$(INITRD_DIR)/dtc-xen ; fi

# The soap server
	for i in $(SBIN_SH_SCRIPTS) ; do $(INSTALL) -m 0755 src/$$i $(DESTDIR)$(USRSBIN_DIR)/$$i ;  done
	for i in $(BIN_SH_SCRIPTS) ; do $(INSTALL) -m 0755 src/$$i $(DESTDIR)$(USRBIN_DIR)/$$i ;  done
	for i in $(THIRD_PARTY) ; do $(INSTALL) -m 0755 3rdparty/$$i $(DESTDIR)$(SHARE_DIR)/dtc-xen/$$i ; done

# The utilities used by the soap server
	$(INSTALL) -m 0755 src/dtc-xen_userconsole $(DESTDIR)/usr/bin/dtc-xen_userconsole

# DTC autodeploy script
	$(INSTALL) -m 0755 src/dtc-panel_autodeploy.sh $(DESTDIR)$(SHARE_DIR)/dtc-xen/dtc-panel_autodeploy.sh
	$(INSTALL) -m 0644 src/selection_config_file $(DESTDIR)$(SHARE_DIR)/dtc-xen/selection_config_file
# The parameter parser
	$(INSTALL) -m 0755 src/dtc-xen-parse-param $(DESTDIR)$(SHARE_DIR)/dtc-xen/dtc-xen-parse-param

# Some configuration files
	$(INSTALL) -m 0644 src/bashrc $(DESTDIR)$(SYSCONFIG_DIR)/dtc-xen/bashrc
	$(INSTALL) -m 0644 src/motd $(DESTDIR)$(SYSCONFIG_DIR)/dtc-xen/motd

# man pages
	$(INSTALL_DIR) -m 0775 $(DESTDIR)$(MAN_DIR)/man8
	$(INSTALL_DIR) -m 0775 $(DESTDIR)$(MAN_DIR)/man1
	for i in $(MAN8_PAGES) ; do cp doc/$$i $(DESTDIR)$(MAN_DIR)/man8/ ; gzip -9 $(DESTDIR)$(MAN_DIR)/man8/$$i ; chmod 0644 $(DESTDIR)$(MAN_DIR)/man8/$$i.gz ; done
	cp doc/dtc-xen_userconsole.1 $(DESTDIR)$(MAN_DIR)/man1/ ; gzip -9 $(DESTDIR)$(MAN_DIR)/man1/dtc-xen_userconsole.1 ; chmod 0644 $(DESTDIR)$(MAN_DIR)/man1/dtc-xen_userconsole.1.gz

# A bit of doc
#	if [ $(DISTRO) = "centos" ] ; then \
#		$(INSTALL) -m 0640 doc/README.RPM $(DESTDIR)$(SHARE_DOC_DIR)/dtc-xen/README.RPM ; fi

# Our default configuration file
	$(INSTALL) -m 0600 etc/dtc-xen/dtc-xen.conf $(DESTDIR)$(SYSCONFIG_DIR)/dtc-xen/dtc-xen.conf
	if [ ! $(DISTRO) = "debian" ] ; then \
		$(INSTALL) -m 0644 etc/dtc-xen/sources.list $(DESTDIR)$(SYSCONFIG_DIR)/dtc-xen/sources.list ;\
		$(INSTALL) -m 0644 etc/dtc-xen/inittab $(DESTDIR)$(SYSCONFIG_DIR)/dtc-xen/inittab ; fi

# the runtime directories
	for i in $(VARLIB_FOLDERS) ; do $(INSTALL_DIR) -m 0750 $(DESTDIR)$(VARLIB_DIR)/dtc-xen/$$i ; done
	$(INSTALL_DIR) -m 0757 $(DESTDIR)$(VARLIB_DIR)/dtc-xen/ttyssh_home

dist:
	./dist

deb:
	./deb

rpm:
	$(MAKE) dist
	VERS=`head -n 1 debian/changelog | cut -d'(' -f2 | cut -d')' -f1 | cut -d'-' -f1` ; \
	PKGNAME=`head -n 1 debian/changelog | cut -d' ' -f1` ; \
	cd .. ; rpmbuild -ta $${PKGNAME}-$${VERS}.tar.gz

.PHONY: dist deb rpm install install_dtc-xen-firewall clean default
