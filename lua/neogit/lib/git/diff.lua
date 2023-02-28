local a = require("plenary.async")
local util = require("neogit.lib.util")
local logger = require("neogit.logger")
local cli = require("neogit.lib.git.cli")
local Collection = require("neogit.lib.collection")
local md5 = require("neogit.lib.md5")

local function parse_diff_stats(raw)
  if type(raw) == "string" then
    raw = vim.split(raw, ", ")
  end
  local stats = {
    additions = 0,
    deletions = 0,
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

local function build_diff_header(output)
  local header = {}
  local start_idx = 1

  for i, line in ipairs(output) do
    if line:match("^@@@*.*@@@*") then
      start_idx = i
      break
    end

    table.insert(header, line)
  end

  return header, start_idx
end

local function build_type(header)
  local kind = "modified"
  local info = {}
  local file = ""
  local header_count = #header

  if header_count >= 4 and header[2]:match("^similarity index") then
    kind = "renamed"

    info = { header[3], header[4] }

    file = ("%s -> %s"):format(info[1]:match("rename from (.*)"), info[2]:match("rename to (.*)"))
  else
    if header_count == 4 then
      -- kind = modified
      file = header[3]:match("%-%-%- a/(.*)")
    elseif header_count == 5 then
      kind = header[2]:match("(.*) mode %d+")

      if kind == "new file" then
        file = header[5]:match("%+%+%+ b/(.*)")
      elseif kind == "deleted file" then
        file = header[4]:match("%-%-%- a/(.*)")
      end
    else
      logger.debug(vim.inspect(header))
    end
  end

  return kind, info, file
end

local function build_lines(output, start_idx)
  local lines = {}

  if start_idx == 1 then
    lines = output
  else
    local insert = table.insert
    for _, line in ipairs(output) do
      insert(lines, line)
    end
  end

  return lines
end

local function build_hunks(lines)
  local hunks = {}
  local hunk = nil
  local hunk_content = ""
  local index_from, index_len, disk_from, disk_len

  for i, line in ipairs(lines) do
    if not line:match("^%+%+%+") then
      if line:match("^@@@") then
        -- Combined diff header
        index_from, index_len, disk_from, disk_len = line:match("@@@* %-(%d+),?(%d*) .* %+(%d+),?(%d*) @@@*")
      else
        -- Normal diff header
        index_from, index_len, disk_from, disk_len = line:match("@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
      end

      if index_from then
        if hunk ~= nil then
          hunk.hash = md5.sumhexa(hunk_content)
          hunk_content = ""
          table.insert(hunks, hunk)
        end

        hunk = {
          index_from = tonumber(index_from),
          index_len = tonumber(index_len) or 1,
          disk_from = tonumber(disk_from),
          disk_len = tonumber(disk_len) or 1,
          line = line,
          diff_from = i,
          diff_to = i,
        }
      else
        hunk_content = hunk_content .. "\n" .. line

        if hunk then
          hunk.diff_to = hunk.diff_to + 1
        end
      end
    end
  end

  if hunk then
    hunk.hash = md5.sumhexa(hunk_content)
    table.insert(hunks, hunk)
  end

  return hunks
end

local function parse_diff(output)
  local header, start_idx = build_diff_header(output)
  local lines = build_lines(output, start_idx)
  local kind, info, file = build_type(header)

  local mt = {
    __index = function(self, method)
      if method == "hunks" then
        self.hunks = self._hunks()
        return self.hunks
      end
    end,
  }

  local diff = {
    kind = kind,
    lines = lines,
    file = file,
    info = info,
    _hunks = function()
      return build_hunks(lines)
    end,
  }

  setmetatable(diff, mt)

  return diff
end

local diff = {
  parse = parse_diff,
  parse_stats = parse_diff_stats,
  get_stats = function(name)
    return parse_diff_stats(cli.diff.no_ext_diff.shortstat.files(name).call_sync():trim())
  end,
}

local ItemFilter = {}

function ItemFilter.new(tbl)
  return setmetatable(tbl, { __index = ItemFilter })
end

function ItemFilter.accepts(tbl, section, item)
  for _, f in ipairs(tbl) do
    if (f.section == "*" or f.section == section) and (f.file == "*" or f.file == item) then
      return true
    end
  end

  return false
end

function diff.register(meta)
  meta.load_diffs = function(repo, filter)
    filter = filter or false
    local executions = {}

    if type(filter) == "table" then
      filter = ItemFilter.new(Collection.new(filter):map(function(item)
        local section, file = item:match("^([^:]+):(.*)$")
        if not section then
          error("Invalid filter item: " .. item, 3)
        end

        return { section = section, file = file }
      end))
    end

    for _, f in ipairs(repo.unstaged.items) do
      if f.mode ~= "D" and f.mode ~= "F" and (not filter or filter:accepts("unstaged", f.name)) then
        table.insert(executions, function()
          local raw_diff = cli.diff.no_ext_diff.files(f.name).call():trim().stdout
          local raw_stats = cli.diff.no_ext_diff.shortstat.files(f.name).call():trim().stdout
          f.diff = parse_diff(raw_diff)
          f.diff.stats = parse_diff_stats(raw_stats)
        end)
      end
    end

    for _, f in ipairs(repo.staged.items) do
      if f.mode ~= "D" and f.mode ~= "F" and (not filter or filter:accepts("staged", f.name)) then
        table.insert(executions, function()
          local raw_diff = cli.diff.no_ext_diff.cached.files(f.name).call():trim().stdout
          local raw_stats = cli.diff.no_ext_diff.cached.shortstat.files(f.name).call():trim().stdout
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
