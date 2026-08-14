local git = require("neogit.lib.git")

---@class NeogitGitSubmodule
local M = {}

---@return string[]
function M.list()
  local result = git.cli.submodule.call({ hidden = true, ignore_error = true }).stdout
  return vim.tbl_map(function(el)
    return vim.split(vim.trim(el), " +", { trimempty = true })[2]
  end, result)
end

return M
