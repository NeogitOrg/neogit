local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")
local config = require("neogit.config")

local commit_header_pat = "([| ]*)(%*?)([| ]*)commit (%w+)"
-- local commit_header_pat = "([| ]*)%*?([| *]*)commit (%w+)"
-- @class CommitLogEntry
-- @field oid the object id of the commit
-- @field level the depth of the commit in the graph
-- @field author_name the name of the author
-- @field author_email the email of the author
-- @field author_date when the author commited
-- @field committer_name the name of the committer
-- @field committer_email the email of the committer
-- @field committer_date when the committer commited
-- @field description a list of lines

--- parses the provided list of lines into a CommitLogEntry
-- @param raw a list of lines
-- @return CommitLogEntry
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

    advance()

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

  local result = cli.log.oneline.max_count(count).show_popup(false).call()

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
