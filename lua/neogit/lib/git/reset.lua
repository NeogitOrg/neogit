local git = require("neogit.lib.git")

---@class NeogitGitReset
local M = {}

---@param target string
---@return boolean
function M.mixed(target)
  local result = git.cli.reset.mixed.args(target).call()
  return result:success()
end

---@param target string
---@return boolean
function M.soft(target)
  local result = git.cli.reset.soft.args(target).call()
  return result:success()
end

---@param target string
---@return boolean
function M.hard(target)
  git.index.create_backup()

  local result = git.cli.reset.hard.args(target).call()
  return result:success()
end

---@param target string
---@return boolean
function M.keep(target)
  local result = git.cli.reset.keep.args(target).call()
  return result:success()
end

---@param target string
---@return boolean
function M.index(target)
  local result = git.cli.reset.args(target).files(".").call()
  return result:success()
end

---@param target string revision to reset to
---@return boolean
function M.worktree(target)
  local success = false
  git.index.with_temp_index(target, function(index)
    local result = git.cli["checkout-index"].all.force.env({ GIT_INDEX_FILE = index }).call()
    success = result:success()
  end)

  return success
end

---@param target string
---@param files string[]
---@return boolean
function M.file(target, files)
  local result = git.cli.checkout.rev(target).files(unpack(files)).call()
  if result:failure() then
    result = git.cli.reset.args(target).files(unpack(files)).call()
  end

  return result:success()
end

return M
