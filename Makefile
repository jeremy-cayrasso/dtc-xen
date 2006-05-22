default:
	@-echo "Building... not..."

clean:	
	if [ -n ""$(DESTDIR) ]; then 	(rm -rf $(DESTDIR)/usr) ;	fi
	@-echo "OK, clean :)"

install:
	@-echo "Copying to $(DESTDIR)..."
	@-mkdir -p $(DESTDIR)/usr/share/dtc-xen
	@-mkdir -p $(DESTDIR)/var/lib/dtc-xen/rrds
	@-mkdir -p $(DESTDIR)/var/www
	@-mkdir -p $(DESTDIR)/etc/cron.d
	@-cp debian/dtc-xen $(DESTDIR)/etc/cron.d
	@-ln -s /usr/share/dtc-xen $(DESTDIR)/var/www/dtc-xen
	@-cp -rf panel/* $(DESTDIR)/usr/share/dtc-xen
	@#now for documentation
	@-mkdir -p $(DESTDIR)/usr/share/doc/dtc-xen
	@-cp -rf doc/* $(DESTDIR)/usr/share/doc/dtc-xen
	@-cp debian/changelog $(DESTDIR)/usr/share/doc/dtc-xen
	@-gzip -9 $(DESTDIR)/usr/share/doc/dtc-xen/changelog
	@-if find $(DESTDIR)/ -iname 'CVS' -exec rm -rf {} \; &>/dev/null ; then \
		echo "Erased CVS dirs" ; \
	fi;
	@-if find $(DESTDIR)/ -iname '*~' -exec rm -rf {} \; &>/dev/null ; then \
		echo "Erased backup files" ; \
	fi;

	@-chown -R root:root $(DESTDIR)/usr
