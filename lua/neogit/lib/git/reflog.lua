local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

local M = {}

---@class RefLogEntry
---@field oid string the object id of the commit
---@field author_name string the name of the author
---@field ref_name string the name of the ref
---@field ref_subject string the subject of the ref

local function parse(entries)
  return util.map(entries, function(entry)
    local hash, author, name, subject = unpack(vim.split(entry, "\30"))
    return {
      oid = hash,
      author_name = author,
      ref_name = name,
      ref_subject = subject
    }
  end)
end

function M.list(refname, options)
  local format = table.concat({
    "%h",    -- Full Hash
    "%aN",   -- Author Name
    "%gd",   -- Reflog Name
    "%gs",   -- Reflog Subject
  }, "%x1E")

  return parse(
    cli.reflog.show.format(format).arg_list(options or {}).date("raw").args(refname).call():trim().stdout
  )
end

return M
