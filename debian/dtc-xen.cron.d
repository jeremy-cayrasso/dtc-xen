* * * * * root	[ -f /usr/share/dtc-xen/graph/xenupdate.py ] && /usr/share/dtc-xen/graph/xenupdate.py /var/lib/dtc-xen/rrds >/dev/null
2,7,12,17,22,27,32,37,42,47,52,57 * * * * root	[ -f /usr/share/dtc-xen/graph/xennetgraph.py ] && /usr/share/dtc-xen/graph/xennetgraph.py /var/lib/dtc-xen/rrds /var/www/dtc-xen/graph/ >/dev/null
4,9,14,19,24,29,34,39,44,49,54,59 * * * * root	[ -f /usr/share/dtc-xen/graph/xencpugraph.py ] && /usr/share/dtc-xen/graph/xencpugraph.py /var/lib/dtc-xen/rrds /var/www/dtc-xen/graph/ >/dev/null
3,8,13,18,23,28,33,38,43,48,53,58 * * * * root	[ -f /usr/share/dtc-xen/graph/xeniograph.py ] && /usr/share/dtc-xen/graph/xeniograph.py /var/lib/dtc-xen/rrds /var/www/dtc-xen/graph/ >/dev/null
