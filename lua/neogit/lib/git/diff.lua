local cli = require("neogit.lib.git.cli")

local function parse_diff(output)
  local header = {}
  local hunks = {}
  local is_header = true

  for i=1,#output do
    if is_header and output[i]:match('^@@.*@@') then
      is_header = false
    end

    if is_header then
      table.insert(header, output[i])
    else
      table.insert(hunks, output[i])
    end
  end

  local diff = {
    lines = hunks,
    hunks = {}
  }

  local len = #hunks

  local hunk = nil

  for i=1,len do
    local line = hunks[i]
    if not vim.startswith(line, "+++") then
      local index_from, index_len, disk_from, disk_len = line:match('@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@')

      if index_from then
        if hunk ~= nil then
          table.insert(diff.hunks, hunk)
        end
        hunk = {
          index_from = tonumber(index_from),
          index_len = tonumber(index_len) or 1,
          disk_from = tonumber(disk_from),
          disk_len = tonumber(disk_len) or 1,
          first = i,
          last = i
        }
      else
        hunk.last = hunk.last + 1
      end
    end
  end

  table.insert(diff.hunks, hunk)

  return diff
end

local diff = {
  parse = parse_diff,
  staged = function(name, original_name, cb)
    local cmd
    if original_name ~= nil then
      cmd = 'diff --cached -- "' .. original_name .. '" "' .. name .. '"'
    else
      cmd = 'diff --cached -- "' .. name .. '"'
    end

    if cb then
      cli.run(cmd, function(o)
        cb(parse_diff(o))
      end)
    else
      return parse_diff(cli.run(cmd))
    end
  end,
  unstaged = function(name, original_name, cb)
    local cmd
    if original_name ~= nil then
      cmd = 'diff -- "' .. original_name .. '" "' .. name .. '"'
    else
      cmd = 'diff -- "' .. name .. '"'
    end

    if cb then
      cli.run(cmd, function(o)
        cb(parse_diff(o))
      end)
    else
      return parse_diff(cli.run(cmd))
    end
  end,
}

return diff
