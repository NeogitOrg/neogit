local cli = require("neogit.lib.git.cli")
local Path = require("plenary.path")

local M = {}

function M.relpath_from_repository(path)
  local result = cli["ls-files"].others.cached.modified.deleted.full_name
    .cwd("<current>")
    .args(path)
    .show_popup(false)
    .call()
  return result.stdout[1]
end

---Finds files within .git/ dir
---@param name_pattern string|nil
---@param path_pattern string|nil
---@param opts table|nil
---@return string|table|nil
function M.git_dir(name_pattern, path_pattern, opts)
  opts = opts or {}
  opts.path = cli.git_root() .. "/" .. cli.git_dir_path_sync() .. "/"
  opts.limit = opts.limit or 1
  opts.type = opts.type or "file"

  local found = vim.fs.find(function(name, path)
    return name:match(name_pattern or ".") and path:match(path_pattern or ".")
  end, opts)

  if opts.limit == 1 then
    return found[1]
  else
    return found
  end
end

---Reads file and returns matching lines
---@param filepath string
---@param pattern string
---@return table
function M.line_match(filepath, pattern)
  local matches = {}
  for line in Path:new(filepath):iter() do
    if line:match(pattern) then
      table.insert(matches, line)
    end
  end
  return matches
end

return M
