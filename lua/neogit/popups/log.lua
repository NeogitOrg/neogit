local popup = require("neogit.lib.popup")
local LogViewBuffer = require 'neogit.buffers.log_view'
local git = require("neogit.lib.git")
local util = require 'neogit.lib.util'

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

local function create()
  popup.deprecated_create(
    "NeogitLogPopup",
    {
      {
        key = "g",
        description = "Show graph",
        cli = "graph",
        enabled = true
      },
      {
        key = "c",
        description = "Show graph in color",
        cli = "color",
        enabled = true,
        parse = false
      },
      {
        key = "d",
        description = "Show refnames",
        cli = "decorate",
        enabled = true
      },
      {
        key = "S",
        description = "Show signatures",
        cli = "show-signature",
        enabled = false
      },
      {
        key = "u",
        description = "Show diffs",
        cli = "patch",
        enabled = false
      },
      {
        key = "s",
        description = "Show diffstats",
        cli = "stat",
        enabled = false
      },
      {
        key = "D",
        description = "Simplify by decoration",
        cli = "simplify-by-decoration",
        enabled = false
      },
      {
        key = "f",
        description = "Follow renames when showing single-file log",
        cli = "follow",
        enabled = false
      },
    },
    {
      {
        key = "n",
        description = "Limit number of commits",
        cli = "max-count",
        value = "256"
      },
      {
        key = "f",
        description = "Limit to files",
        cli = "-count",
        value = ""
      },
      {
        key = "a",
        description = "Limit to author",
        cli = "author",
        value = ""
      },
      {
        key = "g",
        description = "Search messages",
        cli = "grep",
        value = ""
      },
      {
        key = "G",
        description = "Search changes",
        cli = "",
        value = ""
      },
      {
        key = "S",
        description = "Search occurences",
        cli = "",
        value = ""
      },
      {
        key = "L",
        description = "Trace line evolution",
        cli = "",
        value = ""
      },
    },
    {
      {
        {
          key = "l",
          description = "Log current",
          callback = function(popup)
            local output = git.cli.log.args(unpack(popup.get_arguments())).call_sync()
            LogViewBuffer.new(parse(output)):open()
          end
        },
        {
          key = "o",
          description = "Log other",
          callback = function() end
        },
        {
          key = "h",
          description = "Log HEAD",
          callback = function(popup)
            local output = 
              git.cli.log
                .oneline
                .args(unpack(popup.get_arguments()))
                .for_range('HEAD')
                .call_sync()

            LogViewBuffer.new(parse(output)):open()
          end
        },
      },
      {
        {
          key = "L",
          description = "Log local branches",
          callback = function(popup)
            local output = 
              git.cli.log
                .oneline
                .args(unpack(popup.get_arguments()))
                .branches
                .call_sync()

            LogViewBuffer.new(parse(output)):open()
          end
        },
        {
          key = "b",
          description = "Log all branches",
          callback = function(popup)
            local output = 
              git.cli.log
                .oneline
                .args(unpack(popup.get_arguments()))
                .branches
                .remotes
                .call_sync()
            LogViewBuffer.new(parse(output)):open()
          end
        },
        {
          key = "a",
          description = "Log all references",
          callback = function(popup)
            local output = 
              git.cli.log
                .oneline
                .args(unpack(popup.get_arguments()))
                .all
                .call_sync()
            LogViewBuffer.new(parse(output)):open()
          end
        },
      },
      {
        {
          key = "r",
          description = "Reflog current",
          callback = function() end
        },
        {
          key = "O",
          description = "Reflog other",
          callback = function() end
        },
        {
          key = "H",
          description = "Reflog HEAD",
          callback = function() end
        },
      }
    })
end

return {
  create = create
}
