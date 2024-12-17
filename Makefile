test:
	TEMP_DIR=$$TEMP_DIR TEST_FILES=$$TEST_FILES GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null NVIM_APPNAME=neogit-test nvim --headless -S "./tests/init.lua"

specs:
	bundle install && CI=1 bundle exec rspec --format Fuubar

lint:
	selene --config selene/config.toml lua
	typos

format:
	stylua .

typecheck:
	llscheck lua/

.PHONY: format lint typecheck
