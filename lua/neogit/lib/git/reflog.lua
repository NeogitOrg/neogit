local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local config = require("neogit.config")

---@class NeogitGitReflog
local M = {}

---@class ReflogEntry
---@field oid string the object id of the commit
---@field author_name string the name of the author
---@field ref_name string the name of the ref
---@field ref_subject string the subject of the ref

local function parse(entries)
  local index = -1

  return util.filter_map(entries, function(entry)
    index = index + 1
    local hash, author, name, subject, rel_date, commit_date = unpack(vim.split(entry, "\30"))
    local command, message = subject:match([[^(.-): (.*)]])
    if not command then
      command = subject:match([[^(.-):]])
    end

    if not command then
      return nil
    end

    if command:match("^pull") then
      command = "pull"
    elseif command:match("^merge") then
      message = command:match("^merge (.*)") .. ": " .. message
      command = "merge"
    elseif command:match("^rebase") then
      command = "rebase " .. (command:match("%((.-)%)") or command)
    elseif command:match("commit %(.-%)") then -- amend and merge
      command = command:match("%((.-)%)")
    end

    return {
      oid = hash,
      index = index,
      author_name = author,
      ref_name = name,
      ref_subject = message,
      rel_date = rel_date,
      commit_date = commit_date,
      type = command,
    }
  end)
end

function M.list(refname, options)
  local format = table.concat({
    "%H", -- Full Hash
    "%aN", -- Author Name
    "%gd", -- Reflog Name
    "%gs", -- Reflog Subject
    "%cr", -- Commit Date (Relative)
    "%cd", -- Commit Date
  }, "%x1E")

  util.remove_item_from_table(options, "--simplify-by-decoration")
  util.remove_item_from_table(options, "--follow")

  local date_format
  if config.values.log_date_format ~= nil then
    date_format = "format:" .. config.values.log_date_format
  else
    date_format = "raw"
  end

  return parse(
    git.cli.reflog.show
      .format(format)
      .date(date_format)
      .arg_list(options or {})
      .args(refname, "--")
      .call({ hidden = true }).stdout
  )
end

return M
