local a = require("plenary.async")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local logger = require("neogit.logger")

local insert = table.insert
local sha256 = vim.fn.sha256

-- Module-level diff cache, persists across buffer close/reopen
-- Key: "section:filename", Value: { diff = <Diff>, file_mode = { head, index, worktree } }
local diff_cache = {}

local MAX_CACHE_SIZE = 50  -- Maximum number of cached diffs

local function maybe_evict_cache()
  local keys = vim.tbl_keys(diff_cache)
  if #keys > MAX_CACHE_SIZE then
    -- Simple eviction: remove oldest entries (first half)
    -- Note: Lua tables don't preserve order, so this is approximate
    local to_remove = math.floor(#keys / 2)
    for i = 1, to_remove do
      diff_cache[keys[i]] = nil
    end
    logger.debug("[DIFF] Cache evicted " .. to_remove .. " entries")
  end
end

--- Clear cache for a specific file, section, or all files
---@param section string|nil Section name to clear, or nil to clear all
---@param filename string|nil Filename to clear within section
local function clear_cache(section, filename)
  if section and filename then
    diff_cache[section .. ":" .. filename] = nil
  elseif section then
    -- Clear all entries for a section
    for key in pairs(diff_cache) do
      if key:match("^" .. section .. ":") then
        diff_cache[key] = nil
      end
    end
  else
    -- Clear entire cache
    diff_cache = {}
  end
end

--- Get cached diff if valid (hashes match)
---@param section string
---@param file StatusItem
---@return Diff|nil
local function get_cached_diff(section, file)
  local key = section .. ":" .. file.name
  local cached = diff_cache[key]

  if not cached then
    return nil
  end

  -- Validate cache by comparing file_mode hashes
  -- If file content changed, the hashes will differ
  if file.file_mode then
    if cached.file_mode then
      if cached.file_mode.index ~= file.file_mode.index or
         cached.file_mode.worktree ~= file.file_mode.worktree then
        logger.debug("[DIFF] Cache invalidated for: " .. file.name)
        diff_cache[key] = nil
        return nil
      end
    end
  end

  logger.debug("[DIFF] Cache hit for: " .. file.name)
  return cached.diff
end

--- Store diff in cache with file_mode for invalidation
---@param section string
---@param file StatusItem
---@param diff Diff
local function set_cached_diff(section, file, diff)
  maybe_evict_cache()
  local key = section .. ":" .. file.name
  diff_cache[key] = {
    diff = diff,
    file_mode = file.file_mode and {
      head = file.file_mode.head,
      index = file.file_mode.index,
      worktree = file.file_mode.worktree,
    } or nil,
  }
  logger.debug("[DIFF] Cached diff for: " .. file.name)
end

---@class NeogitGitDiff
---@field parse fun(raw_diff: string[], raw_stats: string[]): Diff
---@field build fun(section: string, file: StatusItem)
---@field staged_stats fun(): DiffStagedStats
---@field clear_cache fun(section: string|nil, filename: string|nil)
---
---@class Diff
---@field kind string
---@field lines string[]
---@field file string
---@field info table
---@field stats table
---@field hunks Hunk
---
---@class DiffStats
---@field additions number
---@field deletions number
---
---@class Hunk
---@field file string
---@field index_from number
---@field index_len number
---@field disk_from number
---@field disk_len number
---@field diff_from number
---@field diff_to number
---@field length number
---@field hash string
---@field first number First line number in buffer
---@field last number Last line number in buffer
---@field lines string[]
---
---@class DiffStagedStats
---@field summary string
---@field files DiffStagedStatsFile
---
---@class DiffStagedStatsFile
---@field path string|nil
---@field changes string|nil
---@field insertions string|nil
---@field deletions string|nil

---@param raw string|string[]
---@return DiffStats
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

---@param output string[]
---@return string[], number
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

---@param header string[]
---@param kind string
---@return string
local function build_file(header, kind)
  if kind == "modified" then
    return header[3]:match("%-%-%- ./(.*)")
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

---@param header string[]
---@return string, string[]
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

---@param output string[]
---@param start_idx number
---@return string[]
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

---@param content string[]
---@return string
local function hunk_hash(content)
  return sha256(table.concat(content, "\n"))
end

---@param lines string[]
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

  for _, hunk in ipairs(hunks) do
    hunk.lines = {}
    for i = hunk.diff_from + 1, hunk.diff_to do
      insert(hunk.lines, lines[i])
    end

    hunk.length = hunk.diff_to - hunk.diff_from
  end

  return hunks
end

---@param raw_diff string[]
---@param raw_stats string[]
---@return Diff
local function parse_diff(raw_diff, raw_stats)
  local header, start_idx = build_diff_header(raw_diff)
  local lines = build_lines(raw_diff, start_idx)
  local hunks = build_hunks(lines)
  local kind, info = build_kind(header)
  local file = build_file(header, kind)
  local stats = parse_diff_stats(raw_stats or {})

  util.map(hunks, function(hunk)
    hunk.file = file
    return hunk
  end)

  return { ---@type Diff
    kind = kind,
    lines = lines,
    file = file,
    info = info,
    stats = stats,
    hunks = hunks,
  }
end

local function build_metatable(f, raw_output_fn, section)
  setmetatable(f, {
    __index = function(self, method)
      if method == "diff" then
        self.diff = a.util.block_on(function()
          logger.debug("[DIFF] Loading diff for: " .. f.name)
          return parse_diff(unpack(raw_output_fn()))
        end)

        -- Cache the loaded diff for future use
        if section then
          set_cached_diff(section, f, self.diff)
        end

        return self.diff
      end
    end,
  })
end

-- Doing a git-diff with untracked files will exit(1) if a difference is observed, which we can ignore.
---@param name string
---@return fun(): table
local function raw_untracked(name)
  return function()
    local diff = git.cli.diff.no_ext_diff.no_index
      .files("/dev/null", name)
      .call({ hidden = true, ignore_error = true }).stdout
    local stats = {}

    return { diff, stats }
  end
end

---@param name string
---@return fun(): table
local function raw_unstaged(name)
  return function()
    local diff = git.cli.diff.no_ext_diff.files(name).call({ hidden = true }).stdout
    local stats = git.cli.diff.no_ext_diff.shortstat.files(name).call({ hidden = true }).stdout

    return { diff, stats }
  end
end

---@param name string
---@return fun(): table
local function raw_staged_unmerged(name)
  return function()
    local diff = git.cli.diff.no_ext_diff.files(name).call({ hidden = true }).stdout
    local stats = git.cli.diff.no_ext_diff.shortstat.files(name).call({ hidden = true }).stdout

    return { diff, stats }
  end
end

---@param name string
---@return fun(): table
local function raw_staged(name)
  return function()
    local diff = git.cli.diff.no_ext_diff.cached.files(name).call({ hidden = true }).stdout
    local stats = git.cli.diff.no_ext_diff.cached.shortstat.files(name).call({ hidden = true }).stdout

    return { diff, stats }
  end
end

---@param name string
---@return fun(): table
local function raw_staged_renamed(name, original)
  return function()
    local diff = git.cli.diff.no_ext_diff.cached.files(name, original).call({ hidden = true }).stdout
    local stats =
      git.cli.diff.no_ext_diff.cached.shortstat.files(name, original).call({ hidden = true }).stdout

    return { diff, stats }
  end
end

---@param section string
---@param file StatusItem
local function build(section, file)
  -- Check cache first (skip for unmerged files - they change frequently during conflict resolution)
  local is_unmerged = section == "staged" and file.mode and file.mode:match("^[UAD][UAD]")
  if not is_unmerged then
    local cached = get_cached_diff(section, file)
    if cached then
      file.diff = cached
      return -- No metatable needed, diff already loaded from cache
    end
  end

  if section == "untracked" then
    build_metatable(file, raw_untracked(file.name), section)
  elseif section == "unstaged" then
    build_metatable(file, raw_unstaged(file.name), section)
  elseif section == "staged" and file.mode == "R" then
    build_metatable(file, raw_staged_renamed(file.name, file.original_name), section)
  elseif section == "staged" and file.mode:match("^[UAD][UAD]") then
    build_metatable(file, raw_staged_unmerged(file.name), section)
  elseif section == "staged" then
    build_metatable(file, raw_staged(file.name), section)
  else
    error("Unknown section: " .. vim.inspect(section))
  end
end

---@return DiffStagedStats
local function staged_stats()
  local raw = git.cli.diff.no_ext_diff.cached.stat.call({ hidden = true }).stdout
  local files = {}
  local summary

  local idx = 1
  local function advance()
    idx = idx + 1
  end

  local function peek()
    return raw[idx]
  end

  while true do
    local line = peek()
    if not line then
      break
    end

    if line:match("^ %d+ file[s ]+changed,") then
      summary = vim.trim(line)
      break
    else
      local file = { ---@type DiffStagedStatsFile
        path = vim.trim(line:match("^ ([^ ]+)")),
        changes = line:match("|%s+(%d+)"),
        insertions = line:match("|%s+%d+ (%+*)"),
        deletions = line:match("|%s+%d+ %+*(%-*)$"),
      }

      insert(files, file)
      advance()
    end
  end

  return {
    summary = summary,
    files = files,
  }
end

return { ---@type NeogitGitDiff
  parse = parse_diff,
  staged_stats = staged_stats,
  build = build,
  clear_cache = clear_cache,
}
