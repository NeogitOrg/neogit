test:
	LUA_PATH="./?.lua" TEST_FILES=$$TEST_FILES NEOGIT_LOG_LEVEL=error NEOGIT_LOG_CONSOLE="sync" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null NVIM_APPNAME=neogit-test nvim --headless -S "./tests/init.lua"

lint:
	selene --config selene/config.toml lua
	typos

lint-short:
	selene --config selene/config.toml --display-style Quiet lua

.PHONY: lint test
