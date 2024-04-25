local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

---@class NeogitGitReflog
local M = {}

---@class ReflogEntry
---@field oid string the object id of the commit
---@field author_name string the name of the author
---@field ref_name string the name of the ref
---@field ref_subject string the subject of the ref

local function parse(entries)
  local index = -1

  return util.map(entries, function(entry)
    index = index + 1
    local hash, author, name, subject, date = unpack(vim.split(entry, "\30"))
    local command, message = subject:match([[^(.-): (.*)]])
    if not command then
      command = subject:match([[^(.-):]])
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
      rel_date = date,
      type = command,
    }
  end)
end

function M.list(refname, options)
  local format = table.concat({
    "%h", -- Full Hash
    "%aN", -- Author Name
    "%gd", -- Reflog Name
    "%gs", -- Reflog Subject
    "%cr", -- Commit Date (Relative)
  }, "%x1E")

  return parse(
    git.cli.reflog.show.format(format).date("raw").arg_list(options or {}).args(refname, "--").call().stdout
  )
end

return M
