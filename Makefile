test:
	GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null NVIM_APPNAME=neogit NEOGIT_LOG_CONSOLE=true NEOGIT_LOG_LEVEL="info" nvim --clean --noplugin -u NORC --headless -S "./tests/init.lua"

lint:
	selene --config selene/config.toml lua

lint-short:
	selene --config selene/config.toml --display-style Quiet lua

.PHONY: lint test
