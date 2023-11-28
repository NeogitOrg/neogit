local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.refs_view.ui")
local popups = require("neogit.popups")
local CommitViewBuffer = require("neogit.buffers.commit_view")
local config = require("neogit.config")
local notification = require("neogit.lib.notification")
local util = require("neogit.lib.util")

--- @class RefsViewBuffer
--- @field is_open boolean whether the buffer is currently shown
--- @field buffer Buffer
--- @field open fun()
--- @field close fun()
--- @see RefsInfo
--- @see Buffer
--- @see Ui
local M = {
  instance = nil,
}

--- Creates a new RefsViewBuffer
--- @return RefsViewBuffer
function M.new(refs)
  local instance = {
    refs = refs,
    head = "HEAD",
    is_open = false,
    buffer = nil,
  }

  setmetatable(instance, { __index = M })
  return instance
end

--- Closes the RefsViewBuffer
function M:close()
  self.is_open = false
  self.buffer:close()
  self.buffer = nil
end

--- Opens the RefsViewBuffer
--- If already open will close the buffer
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
    name = "NeogitRefsView",
    filetype = "NeogitRefsView",
    kind = "tab",
    context_highlight = false,
    autocmds = {
      ["BufUnload"] = function()
        M.instance.is_open = false
      end,
    },
    mappings = {
      v = {
        [popups.mapping_for("CherryPickPopup")] = popups.open("cherry_pick", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("BranchPopup")] = popups.open("branch", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("CommitPopup")] = popups.open("commit", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("PushPopup")] = popups.open("push", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("RebasePopup")] = popups.open("rebase", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("RevertPopup")] = popups.open("revert", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("ResetPopup")] = popups.open("reset", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("TagPopup")] = popups.open("tag", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("PullPopup")] = popups.open("pull"),
        ["d"] = function()
          if not config.check_integration("diffview") then
            notification.error("Diffview integration must be enabled for log diff")
            return
          end

          local dv = require("neogit.integrations.diffview")
          dv.open("log", self.buffer.ui:get_commits_in_selection())
        end,
      },
      n = {
        [popups.mapping_for("CherryPickPopup")] = popups.open("cherry_pick", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("BranchPopup")] = popups.open("branch", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("CommitPopup")] = popups.open("commit", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("PushPopup")] = popups.open("push", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("RebasePopup")] = popups.open("rebase", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("RevertPopup")] = popups.open("revert", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("ResetPopup")] = popups.open("reset", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("TagPopup")] = popups.open("tag", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("PullPopup")] = popups.open("pull"),
        ["q"] = function()
          self:close()
        end,
        ["<esc>"] = function()
          self:close()
        end,
        ["<enter>"] = function()
          CommitViewBuffer.new(self.buffer.ui:get_commits_in_selection()[1]):open()
        end,
        -- ["{"] = function()
        --   pcall(vim.cmd, "normal! zc")
        --
        --   vim.cmd("normal! k")
        --   for _ = vim.fn.line("."), 0, -1 do
        --     if vim.fn.foldlevel(".") > 0 then
        --       break
        --     end
        --
        --     vim.cmd("normal! k")
        --   end
        --
        --   pcall(vim.cmd, "normal! zo")
        --   vim.cmd("normal! zz")
        -- end,
        -- ["}"] = function()
        --   pcall(vim.cmd, "normal! zc")
        --
        --   vim.cmd("normal! j")
        --   for _ = vim.fn.line("."), vim.fn.line("$"), 1 do
        --     if vim.fn.foldlevel(".") > 0 then
        --       break
        --     end
        --
        --     vim.cmd("normal! j")
        --   end
        --
        --   pcall(vim.cmd, "normal! zo")
        --   vim.cmd("normal! zz")
        -- end,
        ["<tab>"] = function()
          local fold = self.buffer.ui:get_fold_under_cursor()
          if fold then
            if fold.options.on_open then
              fold.options.on_open(fold, self.buffer.ui)
            else
              local ok, _ = pcall(vim.cmd, "normal! za")
              if ok then
                fold.options.folded = not fold.options.folded
              end
            end
          end
        end,
        ["d"] = function()
          if not config.check_integration("diffview") then
            notification.error("Diffview integration must be enabled for log diff")
            return
          end

          local dv = require("neogit.integrations.diffview")
          dv.open("log", self.buffer.ui:get_commits_in_selection()[1])
        end,
      },
    },
    render = function()
      return ui.RefsView(self.refs, self.head)
    end,
    after = function()
      vim.cmd([[setlocal nowrap nospell]])
    end,
  }
end

return M
