local logger = require("neogit.logger")
local client = require("neogit.client")
local notification = require("neogit.lib.notification")
local cli = require("neogit.lib.git.cli")

local M = {}

local a = require("plenary.async")

local function fire_rebase_event(data)
  vim.api.nvim_exec_autocmds("User", { pattern = "NeogitRebase", modeline = false, data = data })
end

local function rebase_command(cmd)
  a.util.scheduler()
  return cmd.env(client.get_envs_git_editor()).show_popup(true):in_pty(true).call { verbose = true }
end

---Instant rebase. This is a way to rebase without using the interactive editor
---@param commit string
---@param args string[] list of arguments to pass to git rebase
---@return ProcessResult
function M.instantly(commit, args)
  local result =
    cli.rebase.env({ GIT_SEQUENCE_EDITOR = ":" }).interactive.arg_list(args).commit(commit).call()

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

  local result = rebase_command(cli.rebase.interactive.arg_list(args).args(commit))
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
  local result = rebase_command(cli.rebase.args(branch).arg_list(args))
  if result.code ~= 0 then
    notification.error("Rebasing failed. Resolve conflicts before continuing")
    fire_rebase_event("conflict")
  else
    notification.info("Rebased onto '" .. branch .. "'")
    fire_rebase_event("ok")
  end
end

function M.onto(start, newbase, args)
  local result = rebase_command(cli.rebase.onto.args(newbase, start).arg_list(args))
  if result.code ~= 0 then
    notification.error("Rebasing failed. Resolve conflicts before continuing")
    fire_rebase_event("conflict")
  else
    notification.info("Rebased onto '" .. newbase .. "'")
    fire_rebase_event("ok")
  end
end

---@param commit string rev name of the commit to reword
---@param message string new message to put onto `commit`
---@return nil
function M.reword(commit, message)
  local result = cli.commit.allow_empty.only.message("amend! " .. commit .. "\n\n" .. message).call()
  if result.code ~= 0 then
    return
  end

  result =
    cli.rebase.env({ GIT_SEQUENCE_EDITOR = ":" }).interactive.autosquash.autostash.commit(commit).call()
  if result.code ~= 0 then
    return
  end
  fire_rebase_event("ok")
end

function M.modify(commit)
  local short_commit = require("neogit.lib.git").rev_parse.abbreviate_commit(commit)
  local editor = "nvim -c '%s/^pick \\(" .. short_commit .. ".*\\)/edit \\1/' -c 'wq'"
  local result = cli.rebase
    .env({ GIT_SEQUENCE_EDITOR = editor }).interactive.autosquash.autostash
    .in_pty(true)
    .commit(commit)
    .call()
  if result.code ~= 0 then
    return
  end
  fire_rebase_event { commit = commit, status = "ok" }
end

function M.drop(commit)
  local short_commit = require("neogit.lib.git").rev_parse.abbreviate_commit(commit)
  local editor = "nvim -c '%s/^pick \\(" .. short_commit .. ".*\\)/drop \\1/' -c 'wq'"
  local result = cli.rebase
    .env({ GIT_SEQUENCE_EDITOR = editor }).interactive.autosquash.autostash
    .in_pty(true)
    .commit(commit)
    .call()
  if result.code ~= 0 then
    return
  end
  fire_rebase_event { commit = commit, status = "ok" }
end

function M.continue()
  return rebase_command(cli.rebase.continue)
end

function M.skip()
  return rebase_command(cli.rebase.skip)
end

function M.edit()
  return rebase_command(cli.rebase.edit_todo)
end

local function line_oid(line)
  return vim.split(line, " ")[2]
end

local function format_line(line)
  local sections = vim.split(line, " ")
  sections[2] = sections[2]:sub(1, 7)

  return table.concat(sections, " ")
end

function M.update_rebase_status(state)
  local repo = require("neogit.lib.git.repository")
  if repo.git_root == "" then
    return
  end

  state.rebase = { items = {}, head = nil, current = nil }

  local rebase_file
  local rebase_merge = repo:git_path("rebase-merge")
  local rebase_apply = repo:git_path("rebase-apply")

  if rebase_merge:exists() then
    rebase_file = rebase_merge
  elseif rebase_apply:exists() then
    rebase_file = rebase_apply
  end

  if rebase_file then
    local head = rebase_file:joinpath("head-name")
    if not head:exists() then
      logger.error("Failed to read rebase-merge head")
      return
    end

    state.rebase.head = head:read():match("refs/heads/([^\r\n]+)")

    local done = rebase_file:joinpath("done")
    if done:exists() then
      for line in done:iter() do
        if line:match("^[^#]") and line ~= "" then
          table.insert(state.rebase.items, { name = format_line(line), oid = line_oid(line), done = true })
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
          table.insert(state.rebase.items, { name = format_line(line), oid = line_oid(line) })
        end
      end
    end
  end
end

M.register = function(meta)
  meta.update_rebase_status = M.update_rebase_status
end

return M
