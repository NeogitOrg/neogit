local a = require 'plenary.async_lib'
local async, await, await_all = a.async, a.await, a.await_all
local cli = require('neogit.lib.git.cli')
local util = require('neogit.lib.util')
local Collection = require('neogit.lib.collection')
local md5 = require 'neogit.lib.md5'

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

  local hunk_content = ''
  for i=1,len do
    local line = hunks[i]
    if not vim.startswith(line, "+++") then
      local index_from, index_len, disk_from, disk_len = line:match('@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@')

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
        hunk.diff_to = hunk.diff_to + 1
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
  parse = parse_diff
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
  meta.load_diffs = async(function (repo, filter)
    filter = filter or false
    local executions = {}

    if type(filter) == 'table' then
      filter = ItemFilter.new(Collection.new(filter):map(function (item)
        local section, file = item:match("^([^:]+):(.*)$")
        if not section then error('Invalid filter item: '..item, 3) end

        return { section = section, file = file }
      end))
    end

    for _, f in ipairs(repo.unstaged.files) do
      if f.mode ~= 'D' and f.mode ~= 'F' and (not filter or filter:accepts('unstaged', f.name)) then
        table.insert(executions, async(function (f)
          local result = await(cli.diff.files(f.name).call())
          f.diff = parse_diff(util.split(result, '\n'))
        end)(f))
      end
    end

    for _, f in ipairs(repo.staged.files) do
      if f.mode ~= 'D' and f.mode ~= 'F' and (not filter or filter:accepts('staged', f.name)) then
        table.insert(executions, async(function (f)
          local result = await(cli.diff.cached.files(f.name).call())
          f.diff = parse_diff(util.split(result, '\n'))
        end)(f))
      end
    end

    await_all(executions)
  end)
end

return diff
