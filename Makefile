test:
	nvim --headless --noplugin -c "lua require(\"plenary.test_harness\").test_directory_command('tests/ {minimal_init = \"tests/minimal-init.nvim\"}')"

lint:
	luacheck `find -name  "*.lua"` --codes

.PHONY: lint test
