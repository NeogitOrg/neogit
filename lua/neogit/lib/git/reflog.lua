local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

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
      local type = command:match("%((.-)%)")
      command = "rebase " .. type
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
    cli.reflog.show
      .format(format)
      .date("raw")
      .arg_list(options or {})
      .args(refname, "--")
      .call()
      :trim().stdout
  )
end

return M
