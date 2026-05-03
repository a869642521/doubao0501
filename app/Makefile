# 代理：把所有命令转发到项目根目录
ROOT := $(shell cd .. && pwd)
MAKEFLAGS += --no-print-directory

TARGETS := help dev dev-emu dev-macos dev-web backend \
           android android-emu android-phone \
           ios ios-device simulator macos web phone-setup \
           stop logs logs-nest logs-ai \
           db-reset db-seed clean flutter-get check

.PHONY: $(TARGETS)

$(TARGETS):
	@$(MAKE) -C "$(ROOT)" $@
