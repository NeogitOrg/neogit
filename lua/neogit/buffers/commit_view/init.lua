local Buffer = require("neogit.lib.buffer")
local cli = require 'neogit.lib.git.cli'
local parser = require 'neogit.buffers.commit_view.parsing'
local ui = require 'neogit.buffers.commit_view.ui'

local M = {
  instance = nil
}

-- @class CommitViewBuffer
-- @field is_open whether the buffer is currently shown
-- @field commit_info CommitInfo
-- @field commit_overview CommitOverview
-- @field buffer Buffer
-- @see CommitInfo
-- @see Buffer
-- @see Ui

--- Creates a new CommitViewBuffer
-- @param commit_id the id of the commit
-- @return CommitViewBuffer
function M.new(commit_id, notify)
  local notification
  if notify then
    local notif = require 'neogit.lib.notification'
    notification = notif.create "Parsing commit..."
  end

  local instance = {
    is_open = false,
    commit_info = parser.parse_commit_info(cli.show.format("fuller").args(commit_id).call_sync()),
    commit_overview = parser.parse_commit_overview(cli.show.stat.oneline.args(commit_id).call_sync()),
    buffer = nil
  }

  if notification then
    notification:delete()
  end

  setmetatable(instance, { __index = M })

  return instance
end



function M:close()
  self.is_open = false
  self.buffer:close()
  self.buffer = nil
end


function M:open()
  if M.instance and M.instance.is_open then
    M.instance:close()
  end

  M.instance = self

  if self.is_open then
    return
  end

  self.hovered_component = nil
  self.is_open = true
  self.buffer = Buffer.create {
    name = "NeogitCommitView",
    filetype = "NeogitCommitView",
    kind = "vsplit",
    autocmds = {
      ["CursorMoved"] = function()
        local stack = self.buffer.ui:get_component_stack_under_cursor()

        if self.hovered_component then
          self.hovered_component.options.highlight = nil
        end

        self.hovered_component = stack[2] or stack[1]
        self.hovered_component.options.highlight = "Directory"

        self.buffer.ui:update()
      end,
      ["BufUnload"] = function()
        M.instance.is_open = false
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
        ["<tab>"] = function()
          local c = self.buffer.ui:get_component_under_cursor()

          if c then
            local c = c.parent
            if c.options.tag == "HunkContent" then
              c = c.parent
            end
            if vim.tbl_contains({ "Diff", "Hunk" }, c.options.tag) then
              c.children[2]:toggle_hidden()
              self.buffer.ui:update()
            end
          end
        end
      }
    },
    render = function()
      return ui.CommitView(self.commit_info, self.commit_overview)
    end
  }
end

return M
