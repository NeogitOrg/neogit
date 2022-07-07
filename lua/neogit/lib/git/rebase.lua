local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local logger = require("neogit.logger")

local fmt = string.format
local fn = vim.fn

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
  local output = git.cli.log.format("fuller").args("--graph").call_sync()

  return parse(output)
end

-- FIXME: this should be moved to a place that can be reused
local function get_nvim_remote_editor()
  local neogit_path = debug.getinfo(1, "S").source:sub(2, -31)
  local nvim_path = fn.shellescape(vim.v.progpath)

  local runtimepath_cmd = fn.shellescape(fmt("set runtimepath^=%s", fn.fnameescape(neogit_path)))
  local lua_cmd = fn.shellescape("lua require('neogit.client').client()")

  local shell_cmd = {
    nvim_path,
    "--headless",
    "--clean",
    "--noplugin",
    "-n",
    "-R",
    "-c",
    runtimepath_cmd,
    "-c",
    lua_cmd,
  }

  return table.concat(shell_cmd, " ")
end

-- FIXME: this should be moved to a place that can be reused
local function get_envs_git_editor()
  local nvim_cmd = get_nvim_remote_editor()
  return {
    GIT_SEQUENCE_EDITOR = nvim_cmd,
    GIT_EDITOR = nvim_cmd,
  }
end

function M.run_interactive(commit)
  local envs = get_envs_git_editor()
  local job = git.cli.rebase.interactive.env(envs).args(commit).to_job()

  job.on_exit = function(j)
    if j.code > 0 then
      logger.debug(fmt("Execution of '%s' failed with code %d", j.cmd, j.code))
    end
  end

  job:start()
end

return M
