local cli = require("neogit.lib.git.cli")
local diff_lib = require("neogit.lib.git.diff")
local util = require("neogit.lib.util")
local config = require("neogit.config")

local commit_header_pat = "([| ]*)(%*?)([| ]*)commit (%w+)"
-- local commit_header_pat = "([| ]*)%*?([| *]*)commit (%w+)"
---@class CommitLogEntry
---@field oid string the object id of the commit
---@field level number the depth of the commit in the graph
---@field author_name string the name of the author
---@field author_email string the email of the author
---@field author_date string when the author commited
---@field committer_name string the name of the committer
---@field committer_email string the email of the committer
---@field committer_date string when the committer commited
---@field description string a list of lines
---@field diffs any[]

--- parses the provided list of lines into a CommitLogEntry
-- @param raw a list of lines
-- @return CommitLogEntry[]
local function parse(raw)
  local commits = {}
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

    -- print(line)
    local commit = {}
    local s1, s2, star

    s1, star, s2, commit.oid = line:match(commit_header_pat)

    if not commit.oid or commit.oid == "" then
      error("Failed to parse line: " .. line)
      return
    end

    -- Consume this line
    advance()

    -- print(s1, s2, commit.oid)
    commit.level = util.str_count(s1, "|")

    local start_idx = #s1 + #s2 + #star

    local function lpeek()
      return raw[idx] and raw[idx]:sub(start_idx + 1, -1) or nil
    end

    local map = {
      Merge = function()
        commit.merge = line:match("Merge:%s*(%w+) (%w+)")
      end,
      Author = function(line)
        commit.author_name, commit.author_email = line:match("Author:%s*(.+) <(.+)>")
      end,
      AuthorDate = function(line)
        commit.author_date = line:match("AuthorDate:%s*(.+)")
      end,
      Commit = function(line)
        commit.committer_name, commit.committer_email = line:match("Commit:%s*(.+) <(.+)>")
      end,
      CommitDate = function(line)
        commit.committer_date = line:match("CommitDate:%s*(.+)")
      end,
    }

    while true do
      line = lpeek()

      if not line or line:find("^%s*$") then
        break
      end

      local w = line:match("%w+")
      local handler = map[w]
      if handler then
        handler(line)
      else
        error(string.format("Unhandled git log header: %q at %q", w, line))
      end

      advance()
    end

    commit.description = {}
    commit.diffs = {}

    -- Consume initial whitespace
    advance()

    while true do
      line = lpeek()

      -- The commit message is indented
      if not line or not line:match("^    ") then
        break
      end

      local msg = line:gsub("^%s*", "")
      table.insert(commit.description, msg)
      advance()
    end

    -- Skip the whitespace after the status
    advance()

    -- Read diffs
    local current_diff = {}
    local in_diff = false

    while true do
      line = lpeek()
      -- Parse the last diff, if any, and begin a new one
      if not line or vim.startswith(line, "diff") then
        -- There was a previous diff, parse it
        if in_diff then
          table.insert(commit.diffs, diff_lib.parse(current_diff))
          current_diff = {}
        end
        in_diff = true
      elseif line == "" then -- A blank line signifies end of diffs
        -- Parse the last diff, consume the blankline, and exit
        if in_diff then
          table.insert(commit.diffs, diff_lib.parse(current_diff))
          current_diff = {}
        end
        advance()
        break
      end

      -- Collect each diff separately
      if line and in_diff then
        table.insert(current_diff, line)
      else
        -- If not in a diff, then the log does not contain diffs
        break
      end

      advance()
    end

    table.insert(commits, commit)
  end

  return commits
end

local function parse_log(output)
  if type(output) == "string" then
    output = vim.split(output, "\n")
  end

  local output_len = #output
  local commits = {}

  for i = 1, output_len do
    local level, hash, rest = output[i]:match("([| *]*)([a-zA-Z0-9]+) (.*)")
    if level ~= nil then
      local remote, message = rest:match("%((.-)%) (.*)")
      if remote == nil then
        message = rest
      end

      local commit = {
        level = util.str_count(level, "|"),
        hash = hash,
        remote = remote or "",
        message = message,
      }
      table.insert(commits, commit)
    end
  end

  return commits
end

local function update_recent(state)
  local count = config.values.status.recent_commit_count
  if count < 1 then
    return
  end

  local result = cli.log.oneline.max_count(count).show_popup(false).call():trim()

  state.recent.items = util.map(result.stdout, function(x)
    return { name = x }
  end)
end

return {
  list = function(options)
    options = util.split(options, " ")
    local result = cli.log.oneline.args(unpack(options)).call()
    return parse_log(result.stdout)
  end,
  register = function(meta)
    meta.update_recent = update_recent
  end,
  parse_log = parse_log,
  parse = parse,
}
