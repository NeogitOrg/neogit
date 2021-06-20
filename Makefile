test:
	nvim --headless --noplugin -c "lua require(\"plenary.test_harness\").test_directory_command('tests/ {minimal_init = \"tests/minimal-init.nvim\"}')"

lint:
	selene --config selene/config.toml lua

lint-short:
	selene --config selene/config.toml --display-style Quiet lua

.PHONY: lint test
