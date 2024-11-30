local logger = require("neogit.logger")
local git = require("neogit.lib.git")
local client = require("neogit.client")
local notification = require("neogit.lib.notification")

---@class NeogitGitRebase
local M = {}

local function fire_rebase_event(data)
  vim.api.nvim_exec_autocmds("User", { pattern = "NeogitRebase", modeline = false, data = data })
end

local function rebase_command(cmd)
  return cmd.env(client.get_envs_git_editor()).call { long = true, pty = true }
end

---Instant rebase. This is a way to rebase without using the interactive editor
---@param commit string
---@param args? string[] list of arguments to pass to git rebase
---@return ProcessResult
function M.instantly(commit, args)
  local result = git.cli.rebase.interactive.autostash.autosquash
    .commit(commit)
    .env({ GIT_SEQUENCE_EDITOR = ":" })
    .arg_list(args or {})
    .call { long = true, pty = true }

  if result.code ~= 0 then
    fire_rebase_event { commit = commit, status = "failed" }
  else
    fire_rebase_event { commit = commit, status = "ok" }
  end

  return result
end

function M.rebase_interactive(commit, args)
  if vim.tbl_contains(args, "--root") then
    commit = ""
  end

  local result = rebase_command(git.cli.rebase.interactive.arg_list(args).args(commit))
  if result.code ~= 0 then
    if result.stdout[1]:match("^hint: Waiting for your editor to close the file%.%.%. error") then
      notification.info("Rebase aborted")
      fire_rebase_event { commit = commit, status = "aborted" }
    else
      notification.error("Rebasing failed. Resolve conflicts before continuing")
      fire_rebase_event { commit = commit, status = "conflict" }
    end
  else
    notification.info("Rebased successfully")
    fire_rebase_event { commit = commit, status = "ok" }
  end
end

function M.onto_branch(branch, args)
  local result = rebase_command(git.cli.rebase.args(branch).arg_list(args))
  if result.code ~= 0 then
    notification.error("Rebasing failed. Resolve conflicts before continuing")
    fire_rebase_event("conflict")
  else
    notification.info("Rebased onto '" .. branch .. "'")
    fire_rebase_event("ok")
  end
end

function M.onto(start, newbase, args)
  local result = rebase_command(git.cli.rebase.onto.args(newbase, start).arg_list(args))
  if result.code ~= 0 then
    notification.error("Rebasing failed. Resolve conflicts before continuing")
    fire_rebase_event("conflict")
  else
    notification.info("Rebased onto '" .. newbase .. "'")
    fire_rebase_event("ok")
  end
end

---@param commit string rev name of the commit to reword
---@return ProcessResult|nil
function M.reword(commit)
  local message = table.concat(git.log.full_message(commit), "\n")
  local status = client.wrap(
    git.cli.commit.only.allow_empty.edit.with_message(("amend! %s\n\n%s"):format(commit, message)),
    {
      autocmd = "NeogitCommitComplete",
      msg = {
        success = "Commit Updated",
      },
    }
  )

  if status == 0 then
    return M.instantly(commit)
  end
end

function M.modify(commit)
  local short_commit = git.rev_parse.abbreviate_commit(commit)
  local editor = "nvim -c '%s/^pick \\(" .. short_commit .. ".*\\)/edit \\1/' -c 'wq'"
  local result = git.cli.rebase.interactive.autosquash.autostash
    .commit(commit)
    .in_pty(true)
    .env({ GIT_SEQUENCE_EDITOR = editor })
    .call()
  if result.code ~= 0 then
    return
  end
  fire_rebase_event { commit = commit, status = "ok" }
end

function M.drop(commit)
  local short_commit = git.rev_parse.abbreviate_commit(commit)
  local editor = "nvim -c '%s/^pick \\(" .. short_commit .. ".*\\)/drop \\1/' -c 'wq'"
  local result = git.cli.rebase.interactive.autosquash.autostash
    .commit(commit)
    .in_pty(true)
    .env({ GIT_SEQUENCE_EDITOR = editor })
    .call()
  if result.code ~= 0 then
    return
  end
  fire_rebase_event { commit = commit, status = "ok" }
end

function M.continue()
  return rebase_command(git.cli.rebase.continue)
end

function M.skip()
  return rebase_command(git.cli.rebase.skip)
end

function M.edit()
  return rebase_command(git.cli.rebase.edit_todo)
end

function M.abort()
  return rebase_command(git.cli.rebase.abort)
end

---Find the merge base for HEAD and it's upstream
---@return string|nil
function M.merge_base_HEAD()
  local result =
    git.cli["merge-base"].args("HEAD", "HEAD@{upstream}").call { ignore_error = true, hidden = true }
  if result.code == 0 then
    return result.stdout[1]
  end
end

---@class RebaseItem
---@field action string
---@field oid string
---@field abbreviated_commit string
---@field subject string
---@field done boolean
---@field stopped boolean

---@class RebaseOnto
---@field oid string
---@field subject string
---@field ref string
---@field is_remote boolean

local function rev_name(oid)
  local result = git.cli["name-rev"].name_only.no_undefined
    .refs("refs/heads/*")
    .exclude("*/HEAD")
    .exclude("*/refs/heads/*")
    .args(oid)
    .call { hidden = true, ignore_error = true }

  if result.code == 0 then
    return result.stdout[1]
  else
    return oid
  end
end

---@return boolean
function M.in_progress()
  return git.repo.state.rebase.head ~= nil
end

---@return string|nil
function M.current_HEAD()
  return git.repo.state.rebase.head_oid
end

function M.update_rebase_status(state)
  state.rebase = { items = {}, onto = {}, head_oid = nil, head = nil, current = nil }

  local rebase_file
  local rebase_merge = git.repo:worktree_git_path("rebase-merge")
  local rebase_apply = git.repo:worktree_git_path("rebase-apply")

  if rebase_merge:exists() then
    rebase_file = rebase_merge
  elseif rebase_apply:exists() then
    rebase_file = rebase_apply
  end

  if rebase_file then
    local head = rebase_file:joinpath("head-name")
    if not head:exists() then
      logger.error("Failed to read rebase-merge head-name")
      return
    end

    head = vim.trim(head:read())
    state.rebase.head = head:match("refs/heads/([^\r\n]+)")
    state.rebase.head_oid = git.rev_parse.verify(head)

    local onto = rebase_file:joinpath("onto")
    if onto:exists() then
      state.rebase.onto.oid = vim.trim(onto:read())
      state.rebase.onto.subject = git.log.message(state.rebase.onto.oid)
      state.rebase.onto.ref = rev_name(state.rebase.onto.oid)
      state.rebase.onto.is_remote = not git.branch.exists(state.rebase.onto.ref)
    end

    local done = rebase_file:joinpath("done")
    if done:exists() then
      for line in done:iter() do
        if line:match("^[^#]") and line ~= "" then
          local oid = line:match("^%w+ (%x+)") or line:match("^fixup %-C (%x+)")
          table.insert(state.rebase.items, {
            action = line:match("^(%w+) "),
            oid = oid,
            abbreviated_commit = oid:sub(1, git.log.abbreviated_size()),
            subject = line:match("^%w+ %x+ (.+)$"),
            done = true,
          })
        end
      end
    end

    local cur = state.rebase.items[#state.rebase.items]
    if cur then
      cur.done = false
      cur.stopped = true
      state.rebase.current = #state.rebase.items
    end

    local todo = rebase_file:joinpath("git-rebase-todo")
    if todo:exists() then
      for line in todo:iter() do
        if line:match("^[^#]") and line ~= "" then
          local oid = line:match("^%w+ (%x+)")
          table.insert(state.rebase.items, {
            done = false,
            action = line:match("^(%w+) "),
            oid = oid,
            abbreviated_commit = oid:sub(1, git.log.abbreviated_size()),
            subject = line:match("^%w+ %x+ (.+)$"),
          })
        end
      end
    end

    if onto:exists() then
      table.insert(state.rebase.items, {
        done = false,
        action = "onto",
        oid = state.rebase.onto.oid,
        abbreviated_commit = state.rebase.onto.oid:sub(1, git.log.abbreviated_size()),
        subject = state.rebase.onto.subject,
      })
    end
  end
end

M.register = function(meta)
  meta.update_rebase_status = M.update_rebase_status
end

return M
