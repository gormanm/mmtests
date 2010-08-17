PREFIX = /usr/local
EXEDIR = $(PREFIX)/bin
PM_OBJ_DIR=FA
PMDIR = $(shell perl -V | grep -e "^\s*/usr/local" | head -1)/FA
ifeq ($(PMDIR),)
PMDIR = $(PREFIX)/lib/perl5/FA
endif

INSTALL_SCRIPT = pagealloc-extfrag show-buddyinfo slab-intfrag record-buddyinfo
INSTALL_PERLMOD = Report.pm
INSTALL = install

ifdef V 
VECHO = : 
else 
VECHO = echo "  " 
ARFLAGS = rc
.SILENT:
endif

all:
	echo Nothing to do, install with make install

install-script: install-perlmod
	@$(VECHO) INSTALL_SCRIPT $(DESTDIR)$(EXEDIR)
	$(INSTALL) -d $(DESTDIR)$(EXEDIR)
	for x in $(INSTALL_SCRIPT); do \
		$(INSTALL) -m 755 $$x $(DESTDIR)$(EXEDIR); done

install-perlmod:
	@$(VECHO) INSTALL_PERLMOD $(DESTDIR)$(PMDIR)
	$(INSTALL) -d $(DESTDIR)$(PMDIR)
	for x in $(INSTALL_PERLMOD); do \
		$(INSTALL) -m 644 $(PM_OBJ_DIR)/$$x $(DESTDIR)$(PMDIR); done

install: install-script
