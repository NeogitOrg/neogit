local cwd = vim.fn.getcwd()

vim.fn.system {
  "git",
  "clone",
  "--depth=1",
  "https://github.com/nvim-lua/plenary.nvim",
  vim.fn.getcwd() .. "/tmp/plenary",
}

vim.opt.rtp:prepend(vim.fn.getcwd() .. "/tmp/plenary")
vim.opt.rtp:prepend(vim.fn.getcwd())

vim.cmd("runtime plugin/neogit.lua")
