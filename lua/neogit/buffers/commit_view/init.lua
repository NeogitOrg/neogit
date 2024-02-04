local Buffer = require("neogit.lib.buffer")
local parser = require("neogit.buffers.commit_view.parsing")
local ui = require("neogit.buffers.commit_view.ui")
local git = require("neogit.lib.git")
local config = require("neogit.config")
local popups = require("neogit.popups")
local status_maps = require("neogit.config").get_reversed_status_maps()

local api = vim.api

---@class CommitInfo
---@field oid string Full commit hash
---@field author_email string
---@field author_name string
---@field author_date string
---@field commit_arg string The commit argument passed to `git show`
---@field committer_email string
---@field committer_date string
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
--- @field open fun(self, kind: string)
--- @field close fun()
--- @see CommitInfo
--- @see Buffer
--- @see Ui
local M = {
  instance = nil,
}

---Creates a new CommitViewBuffer
---@param commit_id string the id of the commit/tag
---@param filter? string[] Filter diffs to filepaths in table
---@return CommitViewBuffer
function M.new(commit_id, filter)
  local commit_info =
    git.log.parse(git.cli.show.format("fuller").args(commit_id).call_sync({ trim = false }).stdout)[1]

  commit_info.commit_arg = commit_id

  local commit_overview =
    parser.parse_commit_overview(git.cli.show.stat.oneline.args(commit_id).call_sync().stdout)

  local instance = {
    is_open = false,
    item_filter = filter,
    commit_info = commit_info,
    commit_overview = commit_overview,
    commit_signature = config.values.commit_view.verify_commit and git.log.verify_commit(commit_id) or {},
    buffer = nil,
  }

  setmetatable(instance, { __index = M })

  return instance
end

--- Closes the CommitViewBuffer
function M:close()
  self.is_open = false
  self.buffer:close()
  self.buffer = nil
end

---Opens the CommitViewBuffer
---If already open will close the buffer
---@param kind? string
function M:open(kind)
  kind = kind or config.values.commit_view.kind

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
    kind = kind,
    context_highlight = true,
    autocmds = {
      ["BufUnload"] = function()
        M.instance.is_open = false
      end,
    },
    mappings = {
      n = {
        ["<cr>"] = function()
          local c = self.buffer.ui:get_component_under_cursor(function(c)
            return c.options.highlight == "NeogitFilePath"
          end)

          if not c then
            return
          end

          -- Some paths are padded for formatting purposes. We need to trim them
          -- in order to use them as match patterns.
          local selected_path = vim.fn.trim(c.value)

          -- Recursively navigate the layout until we hit NeogitDiffHeader leafs
          -- Forward declaration required to avoid missing global error
          local diff_headers = {}
          local function find_diff_headers(layout)
            if layout.children then
              -- One layout element may have multiple children so we need to loop
              for _, val in pairs(layout.children) do
                local v = find_diff_headers(val)
                if v then
                  -- defensive trim
                  diff_headers[vim.fn.trim(v[1])] = v[2]
                end
              end
            else
              if layout.options.line_hl == "NeogitDiffHeader" then
                return { layout.value, layout:row_range_abs() }
              end
            end
          end

          find_diff_headers(self.buffer.ui.layout)

          -- Search for a match and jump if we find it
          for path, line_nr in pairs(diff_headers) do
            -- The gsub is to work around the fact that the OverviewFiles use
            -- => in renames but the diff header uses ->
            if path:gsub(" %-> ", " => "):match(selected_path) then
              -- Save position in jumplist
              vim.cmd("normal! m'")

              self.buffer:move_cursor(line_nr)
              break
            end
          end
        end,
        ["{"] = function() -- Goto Previous
          local function previous_hunk_header(self, line)
            local c = self.buffer.ui:get_component_on_line(line, function(c)
              return c.options.tag == "Diff" or c.options.tag == "Hunk"
            end)

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
          local c = self.buffer.ui:get_component_under_cursor(function(c)
            return c.options.tag == "Diff" or c.options.tag == "Hunk"
          end)

          if c then
            if c.options.tag == "Diff" then
              self.buffer:move_cursor(vim.fn.line(".") + 1)
            else
              local _, last = c:row_range_abs()
              if last == vim.fn.line("$") then
                self.buffer:move_cursor(last)
              else
                self.buffer:move_cursor(last + 1)
              end
            end
            vim.cmd("normal! zt")
          end
        end,
        [popups.mapping_for("CherryPickPopup")] = popups.open("cherry_pick", function(p)
          p { commits = { self.commit_info.oid } }
        end),
        [popups.mapping_for("BranchPopup")] = popups.open("branch", function(p)
          p { commits = { self.commit_info.oid } }
        end),
        [popups.mapping_for("CommitPopup")] = popups.open("commit", function(p)
          p { commit = self.commit_info.oid }
        end),
        [popups.mapping_for("FetchPopup")] = popups.open("fetch"),
        [popups.mapping_for("MergePopup")] = popups.open("merge", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("PushPopup")] = popups.open("push", function(p)
          p { commit = self.commit_info.oid }
        end),
        [popups.mapping_for("RebasePopup")] = popups.open("rebase", function(p)
          p { commit = self.commit_info.oid }
        end),
        [popups.mapping_for("RemotePopup")] = popups.open("remote"),
        [popups.mapping_for("RevertPopup")] = popups.open("revert", function(p)
          p { commits = { self.commit_info.oid } }
        end),
        [popups.mapping_for("ResetPopup")] = popups.open("reset", function(p)
          p { commit = self.commit_info.oid }
        end),
        [popups.mapping_for("TagPopup")] = popups.open("tag", function(p)
          p { commit = self.commit_info.oid }
        end),
        [popups.mapping_for("PullPopup")] = popups.open("pull"),
        ["q"] = function()
          self:close()
        end,
        [status_maps["YankSelected"]] = function()
          local yank = string.format("'%s'", self.commit_info.oid)
          vim.cmd.let("@+=" .. yank)
          vim.cmd.echo(yank)
        end,
        ["<tab>"] = function()
          pcall(vim.cmd, "normal! za")
        end,
        ["<space>"] = function()
          -- require("neogit.lib.ui.debug")
          -- self.buffer.ui:debug_layout()
        end,
      },
    },
    render = function()
      return ui.CommitView(self.commit_info, self.commit_overview, self.commit_signature, self.item_filter)
    end,
    after = function()
      vim.cmd("normal! zR")
    end,
  }
end

return M
