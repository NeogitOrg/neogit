local Buffer = require("neogit.lib.buffer")
local CommitViewBuffer = require 'neogit.buffers.commit_view'
local cli = require 'neogit.lib.git.cli'
local util = require 'neogit.lib.util'
local ui = require 'neogit.buffers.log_view.ui'
local Ui = require 'neogit.lib.ui'

local M = {}

-- @class LogViewBuffer
-- @field is_open whether the buffer is currently shown
-- @field data the dislayed data
-- @field buffer Buffer
-- @see CommitInfo
-- @see Buffer

--- Creates a new LogViewBuffer
-- @param data the data to display
-- @return LogViewBuffer
function M.new(data)
  local instance = {
    is_open = false,
    data = data,
    buffer = nil
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:close()
  self.is_open = false
  self.buffer:close()
  self.buffer = nil
end


function M:open()
  if self.is_open then
    return
  end

  self.hovered_component = nil
  self.is_open = true
  self.buffer = Buffer.create {
    name = "NeogitLogView",
    filetype = "NeogitLogView",
    kind = "split",
    autocmds = {
      ["CursorMoved"] = function()
        local stack = self.buffer.ui:get_component_stack_under_cursor()

        if self.hovered_component then
          self.hovered_component.options.sign = nil
        end

        self.hovered_component = stack[#stack]
        self.hovered_component.options.sign = "NeogitLogViewCursorLine"

        self.buffer.ui:update()
      end
    },
    mappings = {
      n = {
        ["q"] = function()
          self:close()
        end,
        ["F10"] = function()
          self.ui:print_layout_tree { collapse_hidden_components = true }
        end,
        ["<enter>"] = function(buffer)
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]
          buffer:close()
          CommitViewBuffer.new(self.data[c.position.row_start].oid):open()
        end,
        ["<c-k>"] = function(buffer)
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]
          c.children[2].options.hidden = true

          local t_idx = math.max(c.index - 1, 1)
          local target = c.parent.children[t_idx]
          target.children[2].options.hidden = false

          buffer.ui:update()
          self.buffer:move_cursor(target.position.row_start)
        end,
        ["<c-j>"] = function(buffer)
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]
          c.children[2].options.hidden = true

          local t_idx = math.min(c.index + 1, #c.parent.children)
          local target = c.parent.children[t_idx]
          target.children[2].options.hidden = false

          buffer.ui:update()
          buffer:move_cursor(target.position.row_start)
          vim.fn.feedkeys "zz"
        end,
        ["<tab>"] = function()
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]

          c.children[2]:toggle_hidden() 
          self.buffer.ui:update()
          vim.fn.feedkeys "zz"
        end
      }
    },
    render = function(buffer)
      return ui.LogView(self.data)
    end
  }
end

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

return M
