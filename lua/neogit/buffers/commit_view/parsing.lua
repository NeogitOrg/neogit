local M = {}

local util = require("neogit.lib.util")

local CommitOverview = {}

---@param raw table
---@return CommitOverview
function M.parse_commit_overview(raw)
  local overview = {
    summary = util.trim(raw[#raw]),
    files = {},
  }

  for i = 2, #raw - 1 do
    local file = {}
    if raw[i] ~= "" then
      -- matches: tests/specs/neogit/popups/rebase_spec.lua | 2 +-
      file.path, file.changes, file.insertions, file.deletions = raw[i]:match(" (.*)%s+|%s+(%d+) ?(%+*)(%-*)")

      if vim.tbl_isempty(file) then
        -- matches: .../db/b8571c4f873daff059c04443077b43a703338a      | Bin 0 -> 192 bytes
        file.path, file.changes = raw[i]:match(" (.*)%s+|%s+(Bin .*)$")
      end

      table.insert(overview.files, file)
    end
  end

  setmetatable(overview, { __index = CommitOverview })

  return overview
end

return M
