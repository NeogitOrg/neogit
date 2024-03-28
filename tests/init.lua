local util = require("tests.util.util")

if os.getenv("CI") then
  vim.opt.runtimepath:prepend(vim.fn.getcwd())
  vim.cmd([[runtime! plugin/plenary.vim]])
  vim.cmd([[runtime! plugin/neogit.lua]])
else
  util.ensure_installed("nvim-lua/plenary.nvim", util.neogit_test_base_dir)
end

require("plenary.test_harness").test_directory(
  os.getenv("TEST_FILES") == "" and "tests/specs" or os.getenv("TEST_FILES"),
  {
    minimal_init = "tests/minimal_init.lua",
    sequential = true,
  }
)
