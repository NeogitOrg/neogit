local cli = require("neogit.lib.git.cli")

local hunk_header_matcher = vim.regex('^@@.*@@')

local function parse_diff(output)
  local header = {}
  local hunks = {}
  local is_header = true

  for i=1,#output do
    if is_header and hunk_header_matcher:match_str(output[i]) then
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
      local matches = vim.fn.matchlist(line, "^@@ -\\([0-9]*\\),\\?\\([0-9]*\\)\\? +\\([0-9]*\\),\\?\\([0-9]*\\)\\? @@")

      if #matches ~= 0 then
        if hunk ~= nil then
          table.insert(diff.hunks, hunk)
        end
        hunk = {
          index_from = tonumber(matches[2]),
          index_len = tonumber(matches[3]) or 1,
          disk_from = tonumber(matches[4]),
          disk_len = tonumber(matches[5]) or 1,
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
