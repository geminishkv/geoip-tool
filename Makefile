PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
SHAREDIR ?= $(PREFIX)/share/geoip-tool

install:
	install -d "$(BINDIR)"
	install -d "$(SHAREDIR)/bin"
	install -d "$(SHAREDIR)/lib"
	install -m 0755 bin/geoip "$(SHAREDIR)/bin/geoip"
	install -m 0644 lib/geoip_core.sh lib/geoip_lookup.sh lib/geoip_http.sh lib/cmd_banner.sh "$(SHAREDIR)/lib/"
	printf '%s\n' '#!/usr/bin/env bash' > "$(BINDIR)/geoip"
	printf '%s\n' 'exec "$(SHAREDIR)/bin/geoip" "$$@"' >> "$(BINDIR)/geoip"
	chmod 0755 "$(BINDIR)/geoip"

uninstall:
	rm -f "$(BINDIR)/geoip"
	rm -rf "$(SHAREDIR)"

.PHONY: install uninstall