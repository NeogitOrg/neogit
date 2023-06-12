local cli = require("neogit.lib.git.cli")
local diff_lib = require("neogit.lib.git.diff")
local util = require("neogit.lib.util")
local config = require("neogit.config")

local commit_header_pat = "([| ]*)(%*?)([| ]*)commit (%w+)"

---@class CommitLogEntry
---@field oid string the object id of the commit
---@field level number the depth of the commit in the graph
---@field graph string the graph string
---@field author_name string the name of the author
---@field author_email string the email of the author
---@field author_date string when the author commited
---@field committer_name string the name of the committer
---@field committer_email string the email of the committer
---@field committer_date string when the committer commited
---@field description string a list of lines
---@field diffs any[]

---Parses the provided list of lines into a CommitLogEntry
---@param raw string[]
---@return CommitLogEntry[]
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

    local commit = {}
    local s1, s2, star

    s1, star, s2, commit.oid = line:match(commit_header_pat)

    if not commit.oid or commit.oid == "" then
      error("Failed to parse line: " .. line)
      return {}
    end

    -- Consume this line
    advance()

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

---@return CommitLogEntry[]
local function parse_log(output, colored_graph)
  if type(output) == "string" then
    output = vim.split(output, "\n")
  end

  local output_len = #output
  local commits = {}

  for i = 1, output_len do
    local level, hash, subject, author_name, rel_date, ref_name, author_date, committer_name, committer_date, committer_email, author_email, body =
      unpack(vim.split(output[i], "\30"))

    local graph
    if colored_graph then
      graph = colored_graph[i]
    else
      graph = util.trim(level:match("([_|/\\ %*]+)"))
    end

    if level and hash then
      if rel_date then
        rel_date, _ = rel_date:gsub(" ago$", "")
      end

      local commit = {
        level = util.str_count(level, "|"),
        graph = graph,
        oid = hash,
        description = { subject, body },
        author_name = author_name,
        author_email = author_email,
        rel_date = rel_date,
        ref_name = ref_name,
        author_date = author_date,
        committer_date = committer_date,
        committer_name = committer_name,
        committer_email = committer_email,
        body = body,
        -- TODO: Remove below here
        hash = hash,
        message = subject,
      }

      table.insert(commits, commit)
    elseif level then
      if graph ~= commits[#commits].graph then
        table.insert(commits, { graph = graph })
      end
    end
  end

  return commits
end

local M = {}

local format = table.concat({
  "", -- Padding for Graph
  "%H", -- Full Hash
  "%s", -- Subject
  "%aN", -- Author Name
  "%cr", -- Commit Date (Relative)
  "%D", -- Ref Name
  "%ad", -- Author Date
  "%cN", -- Committer Name
  "%cd", -- Committer Date
  "%ce", -- Committer Email
  "%ae", -- Author Email
  "%b", -- Body
}, "%x1E") -- Hex character to split on (dec \30)

---@param options table|nil
---@return CommitLogEntry[]
function M.list(options, show_popup)
  options = options or {}
  show_popup = show_popup or false

  local graph
  if vim.tbl_contains(options, "--color") then
    graph = util.map(
      cli.log.format("%x00").graph.color.arg_list(options or {}).call():trim().stdout_raw,
      function(line)
        return require("neogit.lib.ansi").parse(util.trim(line))
      end
    )
  end

  if
    not vim.tbl_contains(options, function(item)
      return item:match("%-%-max%-count=%d+")
    end, { predicate = true })
  then
    table.insert(options, "--max-count=256")
  end

  local output = cli.log.format(format).graph.arg_list(options or {}).show_popup(show_popup).call():trim()
  return parse_log(output.stdout, graph)
end

local function update_recent(state)
  local count = config.values.status.recent_commit_count
  if count < 1 then
    return
  end

  local result = M.list({ "--max-count=" .. tostring(count) }, false)

  state.recent.items = util.filter_map(result, function(v)
    if v.oid then
      return {
        name = string.format("%s %s", v.oid:sub(1, 7), v.description[1] or "<empty>"),
        oid = v.oid,
        commit = v,
      }
    end
  end)
end

function M.register(meta)
  meta.update_recent = update_recent
end

M.parse = parse

return M
