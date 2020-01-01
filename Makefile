profile ?= local
app_name ?= default
TO_INSTALL = admin_api bin conf profile core lor lualib plugins
NGR_HOME ?= /usr/local/ngr
NGR_BIN ?= /usr/local/bin/ngr
NGR_LOG ?= /var/log/ngr
NGR_HOME_PATH = $(subst /,\\/,$(NGR_HOME))

NGR_ADMIN_HOME ?= /usr/local/ngrAdmin
NGR_ADMIN_BIN ?= /usr/local/bin/ngrAdmin
NGR_ADMIN_LOG ?= /var/log/ngrAdmin
NGR_ADMIN_HOME_PATH = $(subst /,\\/,$(NGR_ADMIN_HOME))


.PHONY: test uninstall-admin uninstall install-Admin install show-admin show

test:
	@echo "to be continued..."

install-admin:
	@rm -rf $(DESTDIR)$(NGR_ADMIN_BIN)
	@rm -rf $(DESTDIR)$(NGR_ADMIN_HOME)/admin_api
	@rm -rf $(DESTDIR)$(NGR_ADMIN_HOME)/bin
	@rm -rf $(DESTDIR)$(NGR_ADMIN_HOME)/conf
	@rm -rf $(DESTDIR)$(NGR_ADMIN_HOME)/profile
	@rm -rf $(DESTDIR)$(NGR_ADMIN_HOME)/core
	@rm -rf $(DESTDIR)$(NGR_ADMIN_HOME)/lor
	@rm -rf $(DESTDIR)$(NGR_ADMIN_HOME)/lualib
	@rm -rf $(DESTDIR)$(NGR_ADMIN_HOME)/plugins

	@if test ! -e "$(DESTDIR)$(NGR_ADMIN_HOME)"; \
	then \
		mkdir -p $(DESTDIR)$(NGR_ADMIN_HOME); \
	fi

	@if test ! -e "$(DESTDIR)$(NGR_ADMIN_LOG)"; \
	then \
		mkdir -p $(DESTDIR)$(NGR_ADMIN_LOG); \
		touch $(DESTDIR)$(NGR_ADMIN_LOG)/access.log; \
	fi

	@for item in $(TO_INSTALL) ; do \
		cp -a $$item $(DESTDIR)$(NGR_ADMIN_HOME)/; \
	done;

	@if test -f "$(DESTDIR)$(NGR_ADMIN_HOME)/profile/config_service/ngr-$(profile).json"; \
	then \
		mv $(DESTDIR)$(NGR_ADMIN_HOME)/profile/config_service/ngr-$(profile).json $(DESTDIR)$(NGR_ADMIN_HOME)/conf/ngr.json; \
	fi

	@rm -r $(DESTDIR)$(NGR_ADMIN_HOME)/profile

	@echo "#!/usr/bin/env resty" >> $(DESTDIR)$(NGR_ADMIN_BIN)
	@echo "package.path=\"$(NGR_ADMIN_HOME)/?.lua;$(NGR_ADMIN_HOME)/lualib/?.lua;;\" .. package.path" >> $(DESTDIR)$(NGR_ADMIN_BIN)
	@echo "package.cpath=\"$(NGR_ADMIN_HOME)/lualib/?.so;;\" .. package.cpath">> $(DESTDIR)$(NGR_ADMIN_BIN)
	@echo "require(\"bin.api_main\")(arg)" >> $(DESTDIR)$(NGR_ADMIN_BIN)
	@chmod +x $(DESTDIR)$(NGR_ADMIN_BIN)
	@echo "NgRouter Admin API server had installed."
	#$(DESTDIR)$(NGR_ADMIN_BIN) help

install:
	@rm -rf $(DESTDIR)$(NGR_BIN)
	@rm -rf $(DESTDIR)$(NGR_HOME)/admin_api
	@rm -rf $(DESTDIR)$(NGR_HOME)/bin
	@rm -rf $(DESTDIR)$(NGR_HOME)/conf
	@rm -rf $(DESTDIR)$(NGR_HOME)/profile
	@rm -rf $(DESTDIR)$(NGR_HOME)/core
	@rm -rf $(DESTDIR)$(NGR_HOME)/lor
	@rm -rf $(DESTDIR)$(NGR_HOME)/lualib
	@rm -rf $(DESTDIR)$(NGR_HOME)/plugins

	@if test ! -e "$(DESTDIR)$(NGR_HOME)"; \
	then \
		mkdir -p $(DESTDIR)$(NGR_HOME); \
	fi

	@if test ! -e "$(DESTDIR)$(NGR_LOG)"; \
	then \
		mkdir -p $(DESTDIR)$(NGR_LOG); \
		touch $(DESTDIR)$(NGR_LOG)/access.log; \
	fi

	@for item in $(TO_INSTALL) ; do \
		cp -a $$item $(DESTDIR)$(NGR_HOME)/; \
	done;

	@if test -f "$(DESTDIR)$(NGR_HOME)/profile/gateway_service/$(app_name)/ngr-$(profile).json"; \
	then \
		mv $(DESTDIR)$(NGR_HOME)/profile/gateway_service/$(app_name)/ngr-$(profile).json $(DESTDIR)$(NGR_HOME)/conf/ngr.json; \
	fi

	@rm -r $(DESTDIR)$(NGR_HOME)/profile

	@echo "#!/usr/bin/env resty" >> $(DESTDIR)$(NGR_BIN)
	@echo "package.path=\"$(NGR_HOME)/?.lua;$(NGR_HOME)/lualib/?.lua;;\" .. package.path" >> $(DESTDIR)$(NGR_BIN)
	@echo "package.cpath=\"$(NGR_HOME)/lualib/?.so;;\" .. package.cpath">> $(DESTDIR)$(NGR_BIN)
	@echo "require(\"bin.main\")(arg)" >> $(DESTDIR)$(NGR_BIN)
	@chmod +x $(DESTDIR)$(NGR_BIN)
	@echo "NgRouter Gateway server had installed."
	#$(DESTDIR)$(NGR_BIN) help

show:
	$(DESTDIR)$(NGR_BIN) help

show-admin:
	$(DESTDIR)$(NGR_ADMIN_BIN) help

uninstall:
	@rm -rf $(DESTDIR)$(NGR_BIN)
	@rm -rf $(DESTDIR)$(NGR_HOME)

uninstall-admin:
	@rm -rf $(DESTDIR)$(NGR_ADMIN_BIN)
	@rm -rf $(DESTDIR)$(NGR_ADMIN_HOME)
