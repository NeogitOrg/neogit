local a = require 'plenary.async'
local util = require 'neogit.lib.util'
local logger = require 'neogit.logger'
local cli = require('neogit.lib.git.cli')
local Collection = require('neogit.lib.collection')
local md5 = require 'neogit.lib.md5'

local function parse_diff_stats(raw)
  if type(raw) == "string" then
    raw = vim.split(raw, ", ")
  end
  local stats = {
    additions = 0,
    deletions = 0
  }
  -- local matches raw:match('1 file changed, (%d+ insertions?%(%+%))?(, )?(%d+ deletions?%(%-%))?')
  for _, part in ipairs(raw) do
    part = util.trim(part)
    local additions = part:match("(%d+) insertion.*")
    local deletions = part:match("(%d+) deletion.*")

    if additions then
      stats.additions = tonumber(additions)
    end

    if deletions then
      stats.deletions = tonumber(deletions)
    end
  end

  return stats
end

local function parse_diff(output, with_stats)
  local diff = {
    kind = "modified",
    lines = {},
    file = "",
    hunks = {},
    stats = {}
  }
  local start_idx = 1

  if with_stats then
    diff.stats = parse_diff_stats(output[1])
    start_idx = 3
  end

  do
    local header = {}

    for i=start_idx,#output do
      if output[i]:match('^@@@*.*@@@*') then
        start_idx = i
        break
      end

      table.insert(header, output[i])
    end

    local header_count = #header
    if header_count == 4 then
      diff.file = header[3]:match("%-%-%- a/(.*)")
    elseif header_count == 5 then
      diff.kind = header[2]:match("(.*) mode %d+")
      if diff.kind == "new file" then
        diff.file = header[5]:match("%+%+%+ b/(.*)")
      elseif diff.kind == "deleted file" then
        diff.file = header[4]:match("%-%-%- a/(.*)")
      end
    else
      logger.debug "TODO: diff parser"
      logger.debug(vim.inspect(header))
    end
  end

  for i=start_idx,#output do
    table.insert(diff.lines, output[i])
  end


  local len = #diff.lines
  local hunk = nil
  local hunk_content = ''

  for i=1,len do
    local line = diff.lines[i]
    if not vim.startswith(line, "+++") then
      local index_from, index_len, disk_from, disk_len
      if vim.startswith(line, "@@@") then
        -- Combined diff header
        index_from, index_len, disk_from, disk_len = line:match('@@@* %-(%d+),?(%d*) .* %+(%d+),?(%d*) @@@*')
      else
        -- Normal diff header
        index_from, index_len, disk_from, disk_len = line:match('@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@')
      end

      if index_from then
        if hunk ~= nil then
          hunk.hash = md5.sumhexa(hunk_content)
          hunk_content = ''
          table.insert(diff.hunks, hunk)
        end
        hunk = {
          index_from = tonumber(index_from),
          index_len = tonumber(index_len) or 1,
          disk_from = tonumber(disk_from),
          disk_len = tonumber(disk_len) or 1,
          line = line,
          diff_from = i,
          diff_to = i
        }
      else
        hunk_content = hunk_content .. '\n' .. line
        if hunk then 
          hunk.diff_to = hunk.diff_to + 1
        end
      end
    end
  end

  if hunk then
    hunk.hash = md5.sumhexa(hunk_content)
    table.insert(diff.hunks, hunk)
  end

  return diff
end

local diff = {
  parse = parse_diff,
  parse_stats = parse_diff_stats,
  get_stats = function(name)
    return parse_diff_stats(cli.diff.no_ext_diff.shortstat.files(name).call_sync())
  end
}

local ItemFilter = {}

function ItemFilter.new (tbl)
  return setmetatable(tbl, { __index = ItemFilter })
end

function ItemFilter.accepts (tbl, section, item)
  for _, f in ipairs(tbl) do
    if (f.section == "*" or f.section == section)
      and (f.file == "*" or f.file == item) then
      return true
    end
  end

  return false
end

function diff.register(meta)
  meta.load_diffs = function (repo, filter)
    filter = filter or false
    local executions = {}

    if type(filter) == 'table' then
      filter = ItemFilter.new(Collection.new(filter):map(function (item)
        local section, file = item:match("^([^:]+):(.*)$")
        if not section then
          error('Invalid filter item: '..item, 3)
        end

        return { section = section, file = file }
      end))
    end

    for _, f in ipairs(repo.unstaged.items) do
      if f.mode ~= 'D' and f.mode ~= 'F' and (not filter or filter:accepts('unstaged', f.name)) then
        table.insert(executions, function ()
          local raw_diff = cli.diff.no_ext_diff.files(f.name).call()
          local raw_stats = cli.diff.no_ext_diff.shortstat.files(f.name).call()
          f.diff = parse_diff(raw_diff)
          f.diff.stats = parse_diff_stats(raw_stats)
        end)
      end
    end

    for _, f in ipairs(repo.staged.items) do
      if f.mode ~= 'D' and f.mode ~= 'F' and (not filter or filter:accepts('staged', f.name)) then
        table.insert(executions, function ()
          local raw_diff = cli.diff.no_ext_diff.cached.files(f.name).call()
          local raw_stats = cli.diff.no_ext_diff.cached.shortstat.files(f.name).call()
          f.diff = parse_diff(raw_diff)
          f.diff.stats = parse_diff_stats(raw_stats)
        end)
      end
    end

    -- If executions is an empty array, the join function blocks forever.
    if #executions > 0 then
      a.util.join(executions)
    end
  end
end

return diff
