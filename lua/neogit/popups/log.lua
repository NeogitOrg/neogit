local popup = require("neogit.lib.popup")
local LogViewBuffer = require("neogit.buffers.log_view")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

local M = {}

local commit_header_pat = "([| ]*)(%*?)([| ]*)commit (%w+)"
-- local commit_header_pat = "([| ]*)%*?([| *]*)commit (%w+)"

local function is_new_commit(line)
  local s1, star, s2, oid = line:match(commit_header_pat)

  print(s1, s2, oid)
  return s1 ~= nil and s2 ~= nil and oid ~= nil
end

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
    print("Peeking: ", idx, raw[idx])
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
      print("Failed to parse line: " .. line)
      return
    end

    -- Consume this line
    advance()

    -- print(s1, s2, commit.oid)
    commit.level = util.str_count(s1, "|")

    local start_idx = #s1 + #s2 + #star

    print(string.format("line: %q %q %q %q %d", line, s1, star, s2, start_idx))

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

      print(string.format("Line: %q", line))
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

      print(string.format("Msgline: %q", line))
      -- The commit message is indented
      if not line or not line:match("^    ") then
        print(string.format("Breaking at: %q", line))
        break
      end

      local msg = line:gsub("^%s*", "")
      table.insert(commit.description, msg)
      advance()
    end

    advance()

    print(vim.inspect(commit))

    table.insert(commits, commit)
  end

  return commits
end

function M.create()
  local p = popup
    .builder()
    :name("NeogitLogPopup")
    :switch("g", "graph", "Show graph", true, false)
    :switch("c", "color", "Show graph in color", true, false)
    :switch("d", "decorate", "Show refnames", true)
    :switch("S", "show-signature", "Show signatures", false)
    :switch("u", "patch", "Show diffs", false)
    :switch("s", "stat", "Show diffstats", false)
    :switch("D", "simplify-by-decoration", "Simplify by decoration", false)
    :switch("f", "follow", "Follow renames when showing single-file log", false)
    :option("n", "max-count", "256", "Limit number of commits")
    :option("f", "count", "", "Limit to files")
    :option("a", "author", "", "Limit to author")
    :option("g", "grep", "", "Search messages")
    -- :option("G", "", "", "Search changes")
    -- :option("S", "", "", "Search occurences")
    -- :option("L", "", "", "Trace line evolution")
    :action(
      "l",
      "Log current",
      function(popup)
        local result = git.cli.log.format("fuller").args("--graph", unpack(popup:get_arguments())).call_sync()
        local parse_args = popup:get_parse_arguments()
        LogViewBuffer.new(parse(result.stdout), parse_args.graph):open()
      end
    )
    :action("o", "Log other")
    :action("h", "Log HEAD", function(popup)
      local result =
        git.cli.log.format("fuller").args(unpack(popup:get_arguments())).for_range("HEAD").call_sync()

      LogViewBuffer.new(parse(result.stdout)):open()
    end)
    :new_action_group()
    :action("b", "Log all branches", function(popup)
      local result =
        git.cli.log.format("fuller").args(unpack(popup:get_arguments())).branches.remotes.call_sync()
      LogViewBuffer.new(parse(result.stdout)):open()
    end)
    :action("a", "Log all references", function(popup)
      local result = git.cli.log.format("fuller").args(unpack(popup:get_arguments())).all.call_sync()
      LogViewBuffer.new(parse(result.stdout)):open()
    end)
    :new_action_group()
    :action("r", "Reflog current")
    :action("O", "Reflog other")
    :action("H", "Reflog HEAD")
    :build()

  p:show()

  return p
end

return M
