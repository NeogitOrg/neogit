local Buffer = require("neogit.lib.buffer")
local cli = require("neogit.lib.git.cli")
local parser = require("neogit.buffers.commit_view.parsing")
local ui = require("neogit.buffers.commit_view.ui")
local log = require("neogit.lib.git.log")
local config = require("neogit.config")
local popups = require("neogit.popups")
local notification = require("neogit.lib.notification")

local api = vim.api

---@class CommitInfo
---@field oid string Full commit hash
---@field author_email string
---@field author_name string
---@field author_date string
---@field commit_arg string The commit argument passed to `git show`
---@field commiter_email string
---@field commiter_date string
---@field description table

---@class CommitOverview
---@field summary string
---@field files table

--- @class CommitViewBuffer
--- @field is_open boolean whether the buffer is currently shown
--- @field commit_info CommitInfo
--- @field commit_signature table|nil
--- @field commit_overview CommitOverview
--- @field buffer Buffer
--- @field open fun()
--- @field close fun()
--- @see CommitInfo
--- @see Buffer
--- @see Ui
local M = {
  instance = nil,
}

--- Creates a new CommitViewBuffer
--- @param commit_id string the id of the commit/tag
--- @param notify boolean Should show a notification or not
--- @return CommitViewBuffer
function M.new(commit_id, notify)
  if notify then
    notification.info("Parsing commit...")
  end

  local commit_info = log.parse(cli.show.format("fuller").args(commit_id).call_sync().stdout)[1]
  commit_info.commit_arg = commit_id
  local instance = {
    is_open = false,
    commit_info = commit_info,
    commit_overview = parser.parse_commit_overview(
      cli.show.stat.oneline.args(commit_id).call_sync():trim().stdout
    ),
    commit_signature = config.values.commit_view.verify_commit and log.verify_commit(commit_id) or {},
    buffer = nil,
  }

  notification.delete_all()

  setmetatable(instance, { __index = M })

  return instance
end

--- Closes the CommitViewBuffer
function M:close()
  self.is_open = false
  self.buffer:close()
  self.buffer = nil
end

--- Opens the CommitViewBuffer
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
    name = "NeogitCommitView",
    filetype = "NeogitCommitView",
    kind = config.values.commit_view.kind,
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
        ["A"] = popups.open("cherry_pick", function(p)
          p { commits = { self.commit_info.oid } }
        end),
        ["b"] = popups.open("branch", function(p)
          p { commits = { self.commit_info.oid } }
        end),
        ["c"] = popups.open("commit", function(p)
          p { commit = self.commit_info.oid }
        end),
        ["r"] = popups.open("rebase", function(p)
          p { commit = self.commit_info.oid }
        end),
        ["v"] = popups.open("revert", function(p)
          p { commits = { self.commit_info.oid } }
        end),
        ["X"] = popups.open("reset", function(p)
          p { commit = self.commit_info.oid }
        end),
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
      return ui.CommitView(self.commit_info, self.commit_overview, self.commit_signature)
    end,
  }
end

return M
