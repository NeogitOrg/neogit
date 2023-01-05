test:
	NEOGIT_LOG_CONSOLE=true NEOGIT_LOG_LEVEL="debug" nvim --headless -c "lua require('plenary.test_harness').test_directory('./tests//', {minimal_init='./tests/init.lua', sequential=true})"

lint:
	selene --config selene/config.toml lua

lint-short:
	selene --config selene/config.toml --display-style Quiet lua

.PHONY: lint test
