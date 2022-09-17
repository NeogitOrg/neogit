local a = require("plenary.async")
local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.commit_select_view.ui")

local M = {}

local function line_pos()
  return vim.fn.getpos(".")[2]
end

function M.new(commits, action)
  local instance = {
    action = action,
    commits = commits,
    buffer = nil,
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:close()
  self.buffer:close()
  self.buffer = nil
end
function M:open()
  self.buffer = Buffer.create {
    name = "NeogitCommitSelectView",
    filetype = "NeogitCommitSelectView",
    kind = "split",
    mappings = {
      n = {
        ["<enter>"] = function()
          local pos = line_pos()
          if self.action then
            a.run(function()
              self.action(self, self.commits[pos])
            end)
          end
        end,
      },
    },
    render = function()
      return ui.View(self.commits)
    end,
  }
end

return M
