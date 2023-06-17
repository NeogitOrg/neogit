local Buffer = require("neogit.lib.buffer")
local cli = require("neogit.lib.git.cli")
local parser = require("neogit.buffers.commit_view.parsing")
local ui = require("neogit.buffers.commit_view.ui")
local log = require("neogit.lib.git.log")

local CherryPickPopup = require("neogit.popups.cherry_pick")

local api = vim.api

local M = {
  instance = nil,
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
    local notif = require("neogit.lib.notification")
    notification = notif.create("Parsing commit...")
  end

  local instance = {
    is_open = false,
    commit_info = log.parse(cli.show.format("fuller").args(commit_id).call_sync().stdout)[1],
    commit_overview = parser.parse_commit_overview(
      cli.show.stat.oneline.args(commit_id).call_sync():trim().stdout
    ),
    buffer = nil,
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
    context_highlight = true,
    autocmds = {
      ["BufUnload"] = function()
        M.instance.is_open = false
      end,
    },
    mappings = {
      n = {
        ["{"] = function() -- Goto Previous
          local function previous_hunk_header(self, line)
            local c = self.buffer.ui:get_component_on_line(line)

            while c and not vim.tbl_contains({ "Diff", "Hunk" }, c.options.tag) do
              c = c.parent
            end

            if c then
              local first, _ = c:row_range_abs()
              if vim.fn.line(".") == first then
                first = previous_hunk_header(self, line - 1)
              end

              return first
            end
          end

          local previous_header = previous_hunk_header(self, vim.fn.line("."))
          if previous_header then
            api.nvim_win_set_cursor(0, { previous_header, 0 })
            vim.cmd("normal! zt")
          end
        end,
        ["}"] = function() -- Goto next
          local c = self.buffer.ui:get_component_under_cursor()

          while c and not vim.tbl_contains({ "Diff", "Hunk" }, c.options.tag) do
            c = c.parent
          end

          if c then
            if c.options.tag == "Diff" then
              api.nvim_win_set_cursor(0, { vim.fn.line(".") + 1, 0 })
            else
              local _, last = c:row_range_abs()
              if last == vim.fn.line("$") then
                api.nvim_win_set_cursor(0, { last, 0 })
              else
                api.nvim_win_set_cursor(0, { last + 1, 0 })
              end
            end
            vim.cmd("normal! zt")
          end
        end,
        ["A"] = function()
          CherryPickPopup.create { commits = { self.commit_info.oid } }
        end,
        ["q"] = function()
          self:close()
        end,
        ["<F10>"] = function()
          self.buffer.ui:print_layout_tree { collapse_hidden_components = true }
        end,
        ["<tab>"] = function()
          local c = self.buffer.ui:get_component_under_cursor()

          if c then
            local c = c.parent
            if c.options.tag == "HunkContent" then
              c = c.parent
            end
            if vim.tbl_contains({ "Diff", "Hunk" }, c.options.tag) then
              local first, _ = c:row_range_abs()
              c.children[2]:toggle_hidden()
              self.buffer.ui:update()
              api.nvim_win_set_cursor(0, { first, 0 })
            end
          end
        end,
      },
    },
    render = function()
      return ui.CommitView(self.commit_info, self.commit_overview)
    end,
  }
end

return M
