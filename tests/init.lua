local util = require("tests.util.util")

if os.getenv("CI") then
  vim.opt.runtimepath:prepend(vim.fn.getcwd())
  vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/tmp/plenary")
  vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/tmp/telescope")

  vim.cmd([[runtime! plugin/plenary.vim]])
  vim.cmd([[runtime! plugin/neogit.lua]])
else
  util.ensure_installed("nvim-lua/plenary.nvim", util.neogit_test_base_dir)
end

local directory = os.getenv("TEST_FILES") == "" and "tests/specs" or os.getenv("TEST_FILES") or "tests/specs"

require("plenary.test_harness").test_directory(directory, {
  minimal_init = "tests/minimal_init.lua",
  sequential = true,
})
