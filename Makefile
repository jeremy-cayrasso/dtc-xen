#!/usr/bin/make -f

# This makefile is left as-is if somebody wants to write a port
# for another platform than debian. Under Debian, it's not needed
# thanks to the dhhelper scripts.

# Set to something else if you want to install elsewhere than /
# but take care of the effects of the "make clean" !!!
# DESTDIR=""

default:
	@-echo "Building... not..."

clean:	
	if [ -n ""$(DESTDIR) -o ! ""$DESTDIR = "/" ]; then 	(rm -rf $(DESTDIR)/) ;	fi
	@-echo "OK, clean :)"

install:
	@-echo "Copying to $(DESTDIR)..."
	@-mkdir -p $(DESTDIR)/usr/share/dtc-xen
	@-mkdir -p $(DESTDIR)/var/lib/dtc-xen/rrds
	@-mkdir -p $(DESTDIR)/var/lib/dtc-xen/states
	@-mkdir -p $(DESTDIR)/var/www
	@-mkdir -p $(DESTDIR)/etc/cron.d
	@-mkdir -p $(DESTDIR)/etc/init.d
	@-mkdir -p $(DESTDIR)/usr/sbin
	# @-mkdir -p $(DESTDIR)/usr/lib/debootstrap/scripts
	@-mkdir -p $(DESTDIR)/usr/lib/dtc-xen
	@-mkdir -p $(DESTDIR)/bin

	@-cp src/dtc-xen_userconsole.sh $(DESTDIR)/bin
	@-cp debian/dtc-xen-soap $(DESTDIR)/etc/init.d
	@-cp debian/dtc-xen $(DESTDIR)/etc/cron.d
	@-ln -s /usr/share/dtc-xen $(DESTDIR)/var/www/dtc-xen
	@-cp -rf panel/* $(DESTDIR)/usr/share/dtc-xen
	@-cp -rf src/dtc_create_vps.sh $(DESTDIR)/usr/sbin/

	@-cp -rf src/dtc_reinstall_os.sh $(DESTDIR)/usr/sbin/
	@-cp -rf src/dtc_setup_vps_disk.sh $(DESTDIR)/usr/sbin/
	@-cp -rf src/dtc_change_bsd_kernel.sh $(DESTDIR)/usr/sbin/
	@-cp -rf src/xm_info_free_memory $(DESTDIR)/usr/sbin/
	@-cp -rf src/vgdisplay_free_size $(DESTDIR)/usr/sbin/
	@-cp -rf src/dtc-soap-server.py $(DESTDIR)/usr/sbin/
	@-cp src/Properties.py $(DESTDIR)/usr/lib/dtc-xen
	# @-cp -rf debootstrap_scripts/dapper $(DESTDIR)/usr/lib/debootstrap/scripts
	@#now for documentation
	@-mkdir -p $(DESTDIR)/usr/share/man/man8
	@-cp doc/dtc_create_vps.sh.8 $(DESTDIR)/usr/share/man/man8
	@-cp -rf doc/dtc_reinstall_os.sh.8 $(DESTDIR)/usr/share/man/man8
	@-cp -rf doc/dtc_setup_vps_disk.sh.8 $(DESTDIR)/usr/share/man/man8
	@-cp -rf doc/dtc_change_bsd_kernel.sh.8 $(DESTDIR)/usr/share/man/man8
	@-mkdir -p $(DESTDIR)/usr/share/doc/dtc-xen
	@-cp -rf doc/todo $(DESTDIR)/usr/share/doc/dtc-xen
	@-cp debian/changelog $(DESTDIR)/usr/share/doc/dtc-xen
	@-gzip -9 $(DESTDIR)/usr/share/doc/dtc-xen/changelog
	@-if find $(DESTDIR)/ -iname 'CVS' -exec rm -rf {} \; &>/dev/null ; then \
		echo "Erased CVS dirs" ; \
	fi;
	@-if find $(DESTDIR)/ -iname '*~' -exec rm -rf {} \; &>/dev/null ; then \
		echo "Erased backup files" ; \
	fi;

	@-chown -R root:root $(DESTDIR)/usr
