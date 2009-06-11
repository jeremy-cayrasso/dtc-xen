#!/usr/bin/make -f

# Set to something else if you want to install elsewhere than /
# but take care of the effects of the "make clean" !!!
# DESTDIR=""

MAN8_PAGES=vgdisplay_free_size.8 dtc-soap-server.8 xm_info_free_memory.8 dtc_change_bsd_kernel.8 dtc_reinstall_os.8 \
dtc_setup_vps_disk.8 dtc-xen_finish_install.8 dtc_install_centos.8 dtc_kill_vps_disk.8 dtc_write_xenpv_conf.8 \
dtc-xen_domUconf_network_debian.8 dtc-xen_domUconf_network_redhat.8 dtc-xen_domUconf_standard.8

SBIN_SH_SCRIPTS=dtc_kill_vps_disk xm_info_free_memory vgdisplay_free_size dtc_setup_vps_disk dtc_reinstall_os \
dtc_change_bsd_kernel dtc_write_xenpv_conf dtc_install_centos dtc-xen_domUconf_standard dtc-xen_domUconf_network_debian \
dtc-xen_domUconf_network_redhat dtc-xen_finish_install dtc-soap-server

default:
	@-echo "Building... not..."

clean:	
	rm $(DESTDIR)/usr/sbin/dtc-soap-server
	rm $(DESTDIR)/usr/share/dtc-xen/Properties.py

	rm $(DESTDIR)/usr/sbin/dtc-xen_finish_install

# The utilities used by the soap server
	rm $(DESTDIR)/bin/dtc-xen_userconsole
	for i in $(SBIN_SH_SCRIPTS) ; do rm $$i ; done

# DTC autodeploy script
	rm $(DESTDIR)/usr/share/dtc-xen/dtc-panel_autodeploy.sh
	rm $(DESTDIR)/usr/share/dtc-xen/selection_config_file

# man pages
	for i in $(MAN8_PAGES) ; do rm $(DESTDIR)/usr/share/man/man8/$$i.gz ; done
	rm $(DESTDIR)/usr/share/man/man1/dtc-xen_userconsole.1.gz

install_dtc-xen-firewall:
	install -D -m 0640 etc/dtc-xen/dtc-xen-firewall-config $(DESTDIR)/etc/dtc-xen/dtc-xen-firewall-config
	install -D -m 0755 etc/init.d/dtc-xen-firewall $(DESTDIR)/etc/init.d/dtc-xen-firewall
	if [ -e debian ] ; then cp etc/init.d/dtc-xen-firewall debian/dtc-xen-firewall.init ; fi

install:
# The soap server
	install -D -m 0700 src/Properties.py $(DESTDIR)/usr/share/dtc-xen/Properties.py
	install -D -m 0755 etc/init.d/dtc-xen $(DESTDIR)/etc/init.d/dtc-xen
	install -D -m 0644 etc/logrotate.d/dtc-xen $(DESTDIR)/etc/logrotate.d/dtc-xen
	if [ -e debian ] ; then cp etc/init.d/dtc-xen debian/dtc-xen.init ; fi

	for i in $(SBIN_SH_SCRIPTS) ; do install -D -m 0700 src/$$i $(DESTDIR)/usr/sbin/$$i ;  done

# The utilities used by the soap server
	install -D -m 0700 src/dtc-xen_userconsole $(DESTDIR)/bin/dtc-xen_userconsole

# DTC autodeploy script
	install -D -m 0740 src/dtc-panel_autodeploy.sh $(DESTDIR)/usr/share/dtc-xen/dtc-panel_autodeploy.sh
	install -D -m 0644 src/selection_config_file $(DESTDIR)/usr/share/dtc-xen/selection_config_file

# Some configuration files
	install -D -m 0640 src/bashrc $(DESTDIR)/etc/dtc-xen/bashrc
	install -D -m 0640 src/motd $(DESTDIR)/etc/dtc-xen/motd

# man pages
	mkdir -p $(DESTDIR)/usr/share/man/man8 $(DESTDIR)/usr/share/man/man1
	for i in $(MAN8_PAGES) ; do cp doc/$$i $(DESTDIR)/usr/share/man/man8/ ; gzip -9 $(DESTDIR)/usr/share/man/man8/$$i ; chmod 0644 $(DESTDIR)/usr/share/man/man8/$$i.gz ; done
	cp doc/dtc-xen_userconsole.1 $(DESTDIR)/usr/share/man/man1/ ; gzip -9 $(DESTDIR)/usr/share/man/man1/dtc-xen_userconsole.1 ; chmod 0644 $(DESTDIR)/usr/share/man/man1/dtc-xen_userconsole.1.gz

# A bit of doc
	install -D -m 0644 doc/examples/dtc_create_vps.conf.sh $(DESTDIR)/usr/share/doc/dtc-xen/examples/dtc_create_vps.conf.sh
	install -D -m 0644 doc/examples/soap.conf $(DESTDIR)/usr/share/doc/dtc-xen/examples/soap.conf

# the runtime directories
	mkdir -p $(DESTDIR)/var/lib/dtc-xen/states $(DESTDIR)/var/lib/dtc-xen/perfdata $(DESTDIR)/var/lib/dtc-xen/ttyssh_home $(DESTDIR)/var/lib/dtc-xen/mnt
