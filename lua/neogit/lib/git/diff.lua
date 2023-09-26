local a = require("plenary.async")
local util = require("neogit.lib.util")
local logger = require("neogit.logger")
local cli = require("neogit.lib.git.cli")

local ItemFilter = require("neogit.lib.item_filter")

local insert = table.insert
local sha256 = vim.fn.sha256

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

  for i = start_idx, #output do
    local line = output[i]
    if line:match("^@@@*.*@@@*") then
      start_idx = i
      break
    end

    insert(header, line)
  end

  return header, start_idx
end

local function build_file(header, kind)
  if kind == "modified" then
    return header[3]:match("%-%-%- a/(.*)")
  elseif kind == "renamed" then
    return ("%s -> %s"):format(header[3]:match("rename from (.*)"), header[4]:match("rename to (.*)"))
  elseif kind == "new file" then
    return header[5]:match("%+%+%+ b/(.*)")
  elseif kind == "deleted file" then
    return header[4]:match("%-%-%- a/(.*)")
  else
    return ""
  end
end

local function build_kind(header)
  local kind = ""
  local info = {}
  local header_count = #header

  if header_count >= 4 and header[2]:match("^similarity index") then
    kind = "renamed"
    info = { header[3], header[4] }
  elseif header_count == 4 then
    kind = "modified"
  elseif header_count == 5 then
    kind = header[2]:match("(.*) mode %d+") or header[3]:match("(.*) mode %d+")
  else
    logger.debug(vim.inspect(header))
  end

  return kind, info
end

local function build_lines(output, start_idx)
  local lines = {}

  if start_idx == 1 then
    lines = output
  else
    for i = start_idx, #output do
      insert(lines, output[i])
    end
  end

  return lines
end

local function hunk_hash(content)
  return sha256(table.concat(content, "\n"))
end

---@class Hunk
---@field index_from number
---@field index_len number
---@field diff_from number
---@field diff_to number

---@return Hunk
local function build_hunks(lines)
  local hunks = {}
  local hunk = nil
  local hunk_content = {}

  for i = 1, #lines do
    local line = lines[i]
    if not line:match("^%+%+%+") then
      local index_from, index_len, disk_from, disk_len

      if line:match("^@@@") then
        -- Combined diff header
        index_from, index_len, disk_from, disk_len = line:match("@@@* %-(%d+),?(%d*) .* %+(%d+),?(%d*) @@@*")
      else
        -- Normal diff header
        index_from, index_len, disk_from, disk_len = line:match("@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
      end

      if index_from then
        if hunk ~= nil then
          hunk.hash = hunk_hash(hunk_content)
          hunk_content = {}
          insert(hunks, hunk)
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
        insert(hunk_content, line)

        if hunk then
          hunk.diff_to = hunk.diff_to + 1
        end
      end
    end
  end

  if hunk then
    hunk.hash = hunk_hash(hunk_content)
    insert(hunks, hunk)
  end

  return hunks
end

local function parse_diff(raw_diff, raw_stats)
  local header, start_idx = build_diff_header(raw_diff)
  local lines = build_lines(raw_diff, start_idx)
  local hunks = build_hunks(lines)
  local kind, info = build_kind(header)
  local file = build_file(header, kind)
  local stats = parse_diff_stats(raw_stats or {})

  return {
    kind = kind,
    lines = lines,
    file = file,
    info = info,
    stats = stats,
    hunks = hunks,
  }
end

local function build_metatable(f, raw_output_fn)
  setmetatable(f, {
    __index = function(self, method)
      if method == "diff" then
        self.diff = a.util.block_on(function()
          logger.debug("[DIFF] Loading diff for: " .. f.name)
          return parse_diff(unpack(raw_output_fn()))
        end)

        return self.diff
      end
    end,
  })

  f.has_diff = true
end

-- Doing a git-diff with untracked files will exit(1) if a difference is observed, which we can ignore.
local function raw_untracked(name)
  return function()
    local diff =
      cli.diff.no_ext_diff.no_index.files("/dev/null", name).call_ignoring_exit_code():trim().stdout
    local stats = {}

    return { diff, stats }
  end
end

local function raw_unstaged(name)
  return function()
    local diff = cli.diff.no_ext_diff.files(name).call():trim().stdout
    local stats = cli.diff.no_ext_diff.shortstat.files(name).call():trim().stdout

    return { diff, stats }
  end
end

local function raw_staged(name)
  return function()
    local diff = cli.diff.no_ext_diff.cached.files(name).call():trim().stdout
    local stats = cli.diff.no_ext_diff.cached.shortstat.files(name).call():trim().stdout

    return { diff, stats }
  end
end

local function raw_staged_renamed(name, original)
  return function()
    local diff = cli.diff.no_ext_diff.cached.files(name, original).call():trim().stdout
    local stats = cli.diff.no_ext_diff.cached.shortstat.files(name, original).call():trim().stdout

    return { diff, stats }
  end
end

local function invalidate_diff(filter, section, item)
  if not filter or filter:accepts(section, item.name) then
    logger.debug("[DIFF] Invalidating cached diff for: " .. item.name)
    item.diff = nil
  end
end

return {
  parse = parse_diff,
  register = function(meta)
    meta.update_diffs = function(repo, filter)
      filter = filter or false
      if filter and type(filter) == "table" then
        filter = ItemFilter.create(filter)
      end

      for _, f in ipairs(repo.untracked.items) do
        invalidate_diff(filter, "untracked", f)
        build_metatable(f, raw_untracked(f.name))
      end

      for _, f in ipairs(repo.unstaged.items) do
        invalidate_diff(filter, "unstaged", f)
        build_metatable(f, raw_unstaged(f.name))
      end

      for _, f in ipairs(repo.staged.items) do
        invalidate_diff(filter, "staged", f)
        if f.mode == "R" then
          build_metatable(f, raw_staged_renamed(f.name, f.original_name))
        else
          build_metatable(f, raw_staged(f.name))
        end
      end
    end
  end,
}
