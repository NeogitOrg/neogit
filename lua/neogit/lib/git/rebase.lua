local util = require("neogit.lib.util")
local logger = require("neogit.logger")
local client = require("neogit.client")

local fmt = string.format
local fn = vim.fn

---@class Rebase: Module
local M = {}

local commit_header_pat = "([| *]*)%*([| *]*)commit (%w+)"

local function is_new_commit(line)
  local s1, s2, oid = line:match(commit_header_pat)

  return s1 ~= nil and s2 ~= nil and oid ~= nil
end

-- NOTE: this is duplicated
local function parse(raw)
  local commits = {}
  local idx = 1

  local function advance()
    idx = idx + 1
    return raw[idx]
  end

  local line = raw[idx]
  while line do
    local commit = {}
    local s1, s2

    s1, s2, commit.oid = line:match(commit_header_pat)
    commit.level = util.str_count(s1, "|") + util.str_count(s2, "|")

    local start_idx = #s1 + #s2 + 1

    local function ladvance()
      local line = advance()
      return line and line:sub(start_idx + 1, -1) or nil
    end

    do
      local line = ladvance()

      if vim.startswith(line, "Merge:") then
        commit.merge = line:match("Merge:%s*(%w+) (%w+)")

        line = ladvance()
      end

      commit.author_name, commit.author_email = line:match("Author:%s*(.+) <(.+)>")
    end

    commit.author_date = ladvance():match("AuthorDate:%s*(.+)")
    commit.committer_name, commit.committer_email = ladvance():match("Commit:%s*(.+) <(.+)>")
    commit.committer_date = ladvance():match("CommitDate:%s*(.+)")

    advance()

    commit.description = {}
    line = advance()

    while line and not is_new_commit(line) do
      table.insert(commit.description, line:sub(start_idx + 5, -1))
      line = advance()
    end

    if line ~= nil then
      commit.description[#commit.description] = nil
    end

    table.insert(commits, commit)
  end

  return commits
end

function M.commits()
  local git = require("neogit.lib.git")
  local output = git.cli.log.format("fuller").args("--graph").call_sync()

  return parse(output)
end

function M.run_interactive(commit)
  local git = require("neogit.lib.git")
  local envs = client.get_envs_git_editor()
  local job = git.cli.rebase.interactive.env(envs).args(commit).to_job()

  vim.notify("Job: " .. vim.inspect(job))

  job.on_exit = function(j)
    if j.code > 0 then
      logger.debug(fmt("Execution of '%s' failed with code %d", j.cmd, j.code))
    end
  end

  job:start()
end

function M.continue()
  local git = require("neogit.lib.git")
  local envs = client.get_envs_git_editor()
  local job = git.cli.rebase.continue.env(envs).to_job()

  job.on_exit = function(j)
    if j.code > 0 then
      logger.debug(fmt("Execution of '%s' failed with code %d", j.cmd, j.code))
    else
      status.refresh(true)
    end
  end

  job:start()
end

local a = require("plenary.async")
local uv = require("neogit.lib.uv")
function M.update_rebase_status(state)
  local cli = require("neogit.lib.git.cli")
  local root = cli.git_root()
  if root == "" then
    return
  end

  local rebase = {
    items = {},
    head = "",
  }

  local _, stat = a.uv.fs_stat(root .. "/.git/rebase-merge")
  local rebase_file = nil

  if stat then
    rebase_file = root .. "/.git/rebase-merge"
  else
    local _, stat = a.uv.fs_stat(root .. "/.git/rebase-apply")
    if stat then
      rebase_file = root .. "/.git/rebase-apply"
    end
  end

  if rebase_file then
    local err, head = uv.read_file(rebase_file .. "/head-name")
    if not head then
      logger.error("Failed to read rebase-merge head: " .. err)
      return
    end
    head = head:match("refs/heads/([^\r\n]+)")
    rebase.head = head

    local _, todos = uv.read_file(rebase_file .. "/git-rebase-todo")

    -- we need \r? to support windows
    for line in (todos or ""):gmatch("[^\r\n]+") do
      if not line:match("^#") then
        table.insert(rebase.items, { name = line })
      end
    end
  end

  state.rebase = rebase
end

M.register = function(meta)
  meta.update_rebase_status = M.update_rebase_status
end

return M
