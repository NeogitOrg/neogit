local popup = require("neogit.lib.popup")
local LogViewBuffer = require 'neogit.buffers.log_view'
local git = require("neogit.lib.git")
local util = require 'neogit.lib.util'

local M = {}

local commit_header_pat = "([| *]*)%*([| *]*)commit (%w+)"

local function is_new_commit(line)
  local s1, s2, oid = line:match(commit_header_pat)

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
    return raw[idx]
  end

  local line = raw[idx]
  while line do
    local commit = {}
    local s1, s2

    s1, s2, commit.oid = line:match(commit_header_pat)
    commit.level = util.str_count(s1, "|") + util.str_count(s2, "|")

    local start_idx = #s1 + #s2 + 1
    
    local function ladvance()
      local line = advance()
      return line and line:sub(start_idx + 1, -1) or nil
    end

    do
      local line = ladvance()

      if vim.startswith(line, "Merge:") then
        commit.merge = line
          :match("Merge:%s*(%w+) (%w+)")

        line = ladvance()
      end

      commit.author_name, commit.author_email = line
        :match("Author:%s*(.+) <(.+)>")
    end

    commit.author_date = ladvance()
      :match("AuthorDate:%s*(.+)")
    commit.committer_name, commit.committer_email = ladvance()
      :match("Commit:%s*(.+) <(.+)>")
    commit.committer_date = ladvance()
      :match("CommitDate:%s*(.+)")

    advance()

    commit.description = {}
    line = advance()

    while line and not is_new_commit(line) do
      table.insert(commit.description, line:sub(start_idx + 5, -1))
      line = advance()
    end

    if line ~= nil then
      commit.description[#commit.description] = nil
    end

    table.insert(commits, commit)
  end

  return commits
end

-- inspect(parse(git.cli.log.args("--max-count=5", "--graph", "--format=fuller").call_sync()))

function M.create()
  local p = popup.builder()
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
    :action("l", "Log current", function(popup)
      local output = git.cli.log.format("fuller").args("--graph", unpack(popup:get_arguments())).call_sync()
      local parse_args = popup:get_parse_arguments()
      LogViewBuffer.new(parse(output), parse_args.graph):open()
    end)
    :action("o", "Log other")
    :action("h", "Log HEAD", function(popup) 
      local output = 
        git.cli.log
          .format("fuller")
          .args(unpack(popup:get_arguments()))
          .for_range('HEAD')
          .call_sync()


      LogViewBuffer.new(parse(output)):open()
    end)
    :new_action_group()
    :action("b", "Log all branches", function(popup)
      local output = 
        git.cli.log
          .format("fuller")
          .args(unpack(popup:get_arguments()))
          .branches
          .remotes
          .call_sync()
      LogViewBuffer.new(parse(output)):open()
    end)
    :action("a", "Log all references", function(popup)
      local output = 
        git.cli.log
          .format("fuller")
          .args(unpack(popup:get_arguments()))
          .all
          .call_sync()
      LogViewBuffer.new(parse(output)):open()
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
