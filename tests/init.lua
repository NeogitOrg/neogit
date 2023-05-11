local cwd = vim.fn.getcwd()
local plenary_path = cwd .. "/tmp/plenary"
local telescope_path = cwd .. "/tmp/telescope"

print("Downloading plenary into: ", plenary_path)
vim.fn.system {
  "git",
  "clone",
  "--depth=1",
  "https://github.com/nvim-lua/plenary.nvim",
  plenary_path,
}

print("Downloading telescope into: ", telescope_path)
vim.fn.system {
  "git",
  "clone",
  "--depth=1",
  "https://github.com/nvim-telescope/telescope.nvim",
  telescope_path,
}

vim.opt.rtp:prepend(plenary_path)
vim.opt.rtp:prepend(telescope_path)
vim.opt.rtp:prepend(cwd)

vim.cmd("runtime plugin/neogit.lua")
