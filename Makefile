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
	@rm -rf $(NGR_ADMIN_BIN)
	@rm -rf $(NGR_ADMIN_HOME)/admin_api
	@rm -rf $(NGR_ADMIN_HOME)/bin
	@rm -rf $(NGR_ADMIN_HOME)/conf
	@rm -rf $(NGR_ADMIN_HOME)/profile
	@rm -rf $(NGR_ADMIN_HOME)/core
	@rm -rf $(NGR_ADMIN_HOME)/lor
	@rm -rf $(NGR_ADMIN_HOME)/lualib
	@rm -rf $(NGR_ADMIN_HOME)/plugins

	@if test ! -e "$(NGR_ADMIN_HOME)"; \
	then \
		mkdir -p $(NGR_ADMIN_HOME); \
	fi

	@if test ! -e "$(NGR_ADMIN_LOG)"; \
	then \
		mkdir -p $(NGR_ADMIN_LOG); \
	fi

	@for item in $(TO_INSTALL) ; do \
		cp -a $$item $(NGR_ADMIN_HOME)/; \
	done;

	@if test -f "$(NGR_ADMIN_HOME)/profile/config_service/ngr-$(profile).json"; \
	then \
		mv $(NGR_ADMIN_HOME)/profile/config_service/ngr-$(profile).json $(NGR_ADMIN_HOME)/conf/ngr.json; \
	fi

	@rm -r $(NGR_ADMIN_HOME)/profile

	@echo "#!/usr/bin/env resty" >> $(NGR_ADMIN_BIN)
	@echo "package.path=\"$(NGR_ADMIN_HOME)/?.lua;$(NGR_ADMIN_HOME)/lualib/?.lua;;\" .. package.path" >> $(NGR_ADMIN_BIN)
	@echo "package.cpath=\"$(NGR_ADMIN_HOME)/lualib/?.so;;\" .. package.cpath">> $(NGR_ADMIN_BIN)
	@echo "require(\"bin.api_main\")(arg)" >> $(NGR_ADMIN_BIN)
	@chmod +x $(NGR_ADMIN_BIN)
	@echo "NgRouter Admin API server had installed."
	$(NGR_ADMIN_BIN) help

install:
	@rm -rf $(NGR_BIN)
	@rm -rf $(NGR_HOME)/admin_api
	@rm -rf $(NGR_HOME)/bin
	@rm -rf $(NGR_HOME)/conf
	@rm -rf $(NGR_HOME)/profile
	@rm -rf $(NGR_HOME)/core
	@rm -rf $(NGR_HOME)/lor
	@rm -rf $(NGR_HOME)/lualib
	@rm -rf $(NGR_HOME)/plugins

	@if test ! -e "$(NGR_HOME)"; \
	then \
		mkdir -p $(NGR_HOME); \
	fi
	
	@if test ! -e "$(NGR_LOG)"; \
	then \
		mkdir -p $(NGR_LOG); \
	fi

	@for item in $(TO_INSTALL) ; do \
		cp -a $$item $(NGR_HOME)/; \
	done;

	@if test -f "$(NGR_HOME)/profile/gateway_service/$(app_name)/ngr-$(profile).json"; \
	then \
		mv $(NGR_HOME)/profile/gateway_service/$(app_name)/ngr-$(profile).json $(NGR_HOME)/conf/ngr.json; \
	fi

	@rm -r $(NGR_HOME)/profile

	@echo "#!/usr/bin/env resty" >> $(NGR_BIN)
	@echo "package.path=\"$(NGR_HOME)/?.lua;$(NGR_HOME)/lualib/?.lua;;\" .. package.path" >> $(NGR_BIN)
	@echo "package.cpath=\"$(NGR_HOME)/lualib/?.so;;\" .. package.cpath">> $(NGR_BIN)
	@echo "require(\"bin.main\")(arg)" >> $(NGR_BIN)
	@chmod +x $(NGR_BIN)
	@echo "NgRouter Gateway server had installed."
	$(NGR_BIN) help

show:
	$(NGR_BIN) help

show-admin:
	$(NGR_ADMIN_BIN) help

uninstall:
	@rm -rf $(NGR_BIN)
	@rm -rf $(NGR_HOME)

uninstall-admin:
	@rm -rf $(NGR_ADMIN_BIN)
	@rm -rf $(NGR_ADMIN_HOME)
