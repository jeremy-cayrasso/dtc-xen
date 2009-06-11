#!/usr/bin/make -f

# Set to something else if you want to install elsewhere than /
# but take care of the effects of the "make clean" !!!
# DESTDIR=""

MAN8_PAGES=vgdisplay_free_size.8 dtc-soap-server.8 xm_info_free_memory.8 dtc_change_bsd_kernel.8 dtc_reinstall_os.8 \
dtc_setup_vps_disk.8 dtc-xen_finish_install.8 dtc_install_centos.8 dtc_kill_vps_disk.8 dtc_write_xenpv_conf.8 \
dtc-xen_domUconf_network_debian.8 dtc-xen_domUconf_network_redhat.8 dtc-xen_domUconf_standard.8

default:
	@-echo "Building... not..."

clean:	
	rm $(DESTDIR)/usr/sbin/dtc-soap-server
	rm $(DESTDIR)/usr/share/dtc-xen/Properties.py

	rm $(DESTDIR)/usr/sbin/dtc-xen_finish_install

# The utilities used by the soap server
	rm $(DESTDIR)/bin/dtc-xen_userconsole
	rm $(DESTDIR)/usr/sbin/dtc_kill_vps_disk
	rm $(DESTDIR)/usr/sbin/xm_info_free_memory
	rm $(DESTDIR)/usr/sbin/vgdisplay_free_size

# VPS setup scripts
	rm $(DESTDIR)/usr/sbin/dtc_setup_vps_disk
	rm $(DESTDIR)/usr/sbin/dtc_reinstall_os
	rm $(DESTDIR)/usr/sbin/dtc_change_bsd_kernel
	rm $(DESTDIR)/usr/sbin/dtc_write_xenpv_conf
	rm $(DESTDIR)/usr/sbin/dtc_install_centos
	rm $(DESTDIR)/usr/sbin/dtc-xen_domUconf_standard
	rm $(DESTDIR)/usr/sbin/dtc-xen_domUconf_network_debian
	rm $(DESTDIR)/usr/sbin/dtc-xen_domUconf_network_redhat

# DTC autodeploy script
	rm $(DESTDIR)/usr/share/dtc-xen/dtc-panel_autodeploy.sh
	rm $(DESTDIR)/usr/share/dtc-xen/selection_config_file

# man pages
	for i in $(MAN8_PAGES) ; do rm $(DESTDIR)/usr/share/man/man8/$$i.gz ; done
	rm $(DESTDIR)/usr/share/man/man1/dtc-xen_userconsole.1.gz

install:
# The soap server
	install -D -m 0700 src/dtc-soap-server.py $(DESTDIR)/usr/sbin/dtc-soap-server
	install -D -m 0700 src/Properties.py $(DESTDIR)/usr/share/dtc-xen/Properties.py

	install -D -m 0740 debian/scripts/dtc-xen_finish_install $(DESTDIR)/usr/sbin/dtc-xen_finish_install

# The utilities used by the soap server
	install -D -m 0700 src/dtc-xen_userconsole.sh $(DESTDIR)/bin/dtc-xen_userconsole
	install -D -m 0700 src/dtc_kill_vps_disk.sh $(DESTDIR)/usr/sbin/dtc_kill_vps_disk
	install -D -m 0700 src/xm_info_free_memory $(DESTDIR)/usr/sbin/xm_info_free_memory
	install -D -m 0700 src/vgdisplay_free_size $(DESTDIR)/usr/sbin/vgdisplay_free_size

# VPS setup scripts
	install -D -m 0700 src/dtc_setup_vps_disk.sh $(DESTDIR)/usr/sbin/dtc_setup_vps_disk
	install -D -m 0700 src/dtc_reinstall_os.sh $(DESTDIR)/usr/sbin/dtc_reinstall_os
	install -D -m 0700 src/dtc_change_bsd_kernel.sh $(DESTDIR)/usr/sbin/dtc_change_bsd_kernel
	install -D -m 0700 src/dtc_write_xenpv_conf.sh $(DESTDIR)/usr/sbin/dtc_write_xenpv_conf
	install -D -m 0700 src/dtc_install_centos.sh $(DESTDIR)/usr/sbin/dtc_install_centos
	install -D -m 0700 src/dtc-xen_domUconf_standard $(DESTDIR)/usr/sbin/dtc-xen_domUconf_standard
	install -D -m 0700 src/dtc-xen_domUconf_network_debian $(DESTDIR)/usr/sbin/dtc-xen_domUconf_network_debian
	install -D -m 0700 src/dtc-xen_domUconf_network_redhat $(DESTDIR)/usr/sbin/dtc-xen_domUconf_network_redhat

# DTC autodeploy script
	install -D -m 0640 src/dtc-panel_autodeploy.sh $(DESTDIR)/usr/share/dtc-xen/dtc-panel_autodeploy.sh
	install -D -m 0644 src/selection_config_file $(DESTDIR)/usr/share/dtc-xen/selection_config_file

# Some configuration files
	install -D -m 0640 src/bashrc $(DESTDIR)/etc/dtc-xen/bashrc
	install -D -m 0640 src/motd $(DESTDIR)/etc/dtc-xen/motd

# man pages
	mkdir -p $(DESTDIR)/usr/share/man/man8 $(DESTDIR)/usr/share/man/man1
	for i in $(MAN8_PAGES) ; do cp doc/$$i $(DESTDIR)/usr/share/man/man8/ ; gzip -9 $(DESTDIR)/usr/share/man/man8/$$i ; chmod 0644 $(DESTDIR)/usr/share/man/man8/$$i.gz ; done
	cp doc/dtc-xen_userconsole.1 $(DESTDIR)/usr/share/man/man1/ ; gzip -9 $(DESTDIR)/usr/share/man/man1/dtc-xen_userconsole.1 ; chmod 0644 $(DESTDIR)/usr/share/man/man1/dtc-xen_userconsole.1.gz

# the runtime directories
	mkdir -p $(DESTDIR)/var/lib/dtc-xen/states $(DESTDIR)/var/lib/dtc-xen/perfdata $(DESTDIR)/var/lib/dtc-xen/ttyssh_home $(DESTDIR)/usr/share/doc/dtc-xen
