local function ensure_installed(repo)
  local name = repo:match(".+/(.+)$")

  local cwd = vim.fn.getcwd()
  local install_path = cwd .. "/tmp/" .. name

  vim.opt.runtimepath:prepend(install_path)

  if not vim.loop.fs_stat(install_path) then
    print("* Downloading " .. name .. " to '" .. install_path .. "/'")
    vim.fn.system { "git", "clone", "--depth=1", "git@github.com:" .. repo .. ".git", install_path }
  end
end

if os.getenv("CI") then
  vim.opt.runtimepath:prepend(vim.fn.getcwd())
  vim.cmd([[runtime! plugin/plenary.vim]])
  vim.cmd([[runtime! plugin/neogit.lua]])
else
  ensure_installed("nvim-lua/plenary.nvim")
  ensure_installed("nvim-telescope/telescope.nvim")
end

require("plenary.test_harness").test_directory("./tests//", {
  minimal_init = "tests/minimal_init.lua",
  sequential = true,
})
