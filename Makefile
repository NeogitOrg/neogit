test:
	GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null NVIM_APPNAME=neogit-test nvim --headless -S "./tests/init.lua"

lint:
	selene --config selene/config.toml lua

lint-short:
	selene --config selene/config.toml --display-style Quiet lua

.PHONY: lint test
