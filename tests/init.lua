local cwd = vim.fn.getcwd()
local plenary_path = cwd .. "/tmp/plenary"

print("Downloading plenary into: ", plenary_path)
vim.fn.system {
  "git",
  "clone",
  "--depth=1",
  "https://github.com/nvim-lua/plenary.nvim",
  plenary_path,
}

vim.opt.rtp:prepend(plenary_path)
vim.opt.rtp:prepend(cwd)

vim.cmd("runtime plugin/neogit.lua")
