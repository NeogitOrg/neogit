local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.log_view.ui")
local config = require("neogit.config")
local popups = require("neogit.popups")
local notification = require("neogit.lib.notification")
local status_maps = require("neogit.config").get_reversed_status_maps()
local CommitViewBuffer = require("neogit.buffers.commit_view")

local M = {}

function M.close()
  self.buffer:close()
  self.buffer = nil
end

function M.open()
  self.buffer = Buffer.create {
    name = "NeogitStashListView",
    filetype = "NeogitStashView",
    kind = config.values.stash.kind,
    context_higlight = true,
    mappings = {
        ["q"] = function()
          self:close()
        end,
        ["<esc>"] = function()
          self:close()
        end,
        ["<enter>"] = function()
          -- Still looking for how to view a stash
          -- CommitViewBuffer.new(self.buffer.ui:get_commit_under_cursor(), self.files):open()
        end,
    }
  }
end

return M
