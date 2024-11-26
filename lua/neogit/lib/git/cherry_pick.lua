local git = require("neogit.lib.git")
local notification = require("neogit.lib.notification")
local util = require("neogit.lib.util")
local client = require("neogit.client")

---@class NeogitGitCherryPick
local M = {}

local function fire_cherrypick_event(data)
  vim.api.nvim_exec_autocmds("User", { pattern = "NeogitCherryPick", modeline = false, data = data })
end

---@param commits string[]
---@param args string[]
---@return boolean
function M.pick(commits, args)
  local cmd = git.cli["cherry-pick"].arg_list(util.merge(args, commits))

  local result
  if vim.tbl_contains(args, "--edit") then
    result = cmd.env(client.get_envs_git_editor()).call { pty = true }
  else
    result = cmd.call { await = true }
  end

  if result.code ~= 0 then
    notification.error("Cherry Pick failed. Resolve conflicts before continuing")
    return false
  else
    fire_cherrypick_event { commits = commits }
    return true
  end
end

function M.apply(commits, args)
  args = util.filter_map(args, function(arg)
    if arg ~= "--ff" then
      return arg
    end
  end)

  local result = git.cli["cherry-pick"].no_commit.arg_list(util.merge(args, commits)).call { await = true }
  if result.code ~= 0 then
    notification.error("Cherry Pick failed. Resolve conflicts before continuing")
  else
    fire_cherrypick_event { commits = commits }
  end
end

---@param commits string[]
---@param src? string
---@param dst string
---@param start? string
---@param checkout_dst? boolean
function M.move(commits, src, dst, args, start, checkout_dst)
  local current = git.branch.current()

  if not git.branch.exists(dst) then
    git.cli.branch.args(start or "", dst).call { hidden = true }
    local upstream = git.branch.upstream(start)
    if upstream then
      git.branch.set_upstream(upstream, dst)
    end
  end

  if dst ~= current then
    git.branch.checkout(dst)
  end

  if not src then
    return git.cherry_pick.pick(commits, args)
  end

  local tip = commits[#commits]
  local keep = commits[1] .. "^"

  if not git.cherry_pick.pick(commits, args) then
    return
  end

  if git.log.is_ancestor(src, tip) then
    git.cli["update-ref"]
      .message(string.format("reset: moving to %s", keep))
      .args(git.rev_parse.full_name(src), keep, tip)
      .call()

    if not checkout_dst then
      git.branch.checkout(src)
    end
  else
    git.branch.checkout(src)

    local editor = "nvim -c '%g/^pick \\(" .. table.concat(commits, ".*|") .. ".*\\)/norm! dd/' -c 'wq'"
    local result =
      git.cli.rebase.interactive.args(keep).in_pty(true).env({ GIT_SEQUENCE_EDITOR = editor }).call()

    if result.code ~= 0 then
      return notification.error("Picking failed - Fix things manually before continuing.")
    end

    if checkout_dst then
      git.branch.checkout(dst)
    end
  end
end

function M.continue()
  git.cli["cherry-pick"].continue.call { await = true }
end

function M.skip()
  git.cli["cherry-pick"].skip.call { await = true }
end

function M.abort()
  git.cli["cherry-pick"].abort.call { await = true }
end

return M
