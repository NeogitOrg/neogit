local Buffer = require("neogit.lib.buffer")
local parser = require("neogit.buffers.commit_view.parsing")
local ui = require("neogit.buffers.commit_view.ui")
local git = require("neogit.lib.git")
local config = require("neogit.config")
local popups = require("neogit.popups")
local commit_view_maps = require("neogit.config").get_reversed_commit_view_maps()
local status_maps = require("neogit.config").get_reversed_status_maps()
local notification = require("neogit.lib.notification")
local jump = require("neogit.lib.jump")
local util = require("neogit.lib.util")

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
---@field summary string a short summary about what happened
---@field files CommitOverviewFile[] a list of CommitOverviewFile

---@class CommitOverviewFile
---@field path string the path to the file relative to the git root
---@field changes string how many changes were made to the file
---@field insertions string insertion count visualized as list of `+`
---@field deletions string deletion count visualized as list of `-`

--- @class CommitViewBuffer
--- @field commit_info CommitInfo
--- @field commit_signature table|nil
--- @field commit_overview CommitOverview
--- @field buffer Buffer
--- @field open fun(self, kind?: string)
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
  local cmd = git.cli.show.format("fuller").args(commit_id)
  if config.values.commit_date_format ~= nil then
    cmd = cmd.args("--date=format:" .. config.values.commit_date_format)
  end
  local commit_info = git.log.parse(cmd.call({ trim = false }).stdout)[1]

  commit_info.commit_arg = commit_id

  local commit_overview =
    parser.parse_commit_overview(git.cli.show.stat.oneline.args(commit_id).call({ hidden = true }).stdout)

  local instance = {
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
  if self.buffer then
    self.buffer:close()
    self.buffer = nil
  end

  M.instance = nil
end

---@return string
function M.current_oid()
  if M.is_open() then
    return M.instance.commit_info.oid
  else
    return "null-oid"
  end
end

---Opens the CommitViewBuffer if it isn't open or performs the given action
---which is passed the window id of the commit view buffer
---@param commit_id string commit
---@param filter string[]? Filter diffs to filepaths in table
---@param cmd string vim command to run in window
function M.open_or_run_in_window(commit_id, filter, cmd)
  assert(commit_id, "commit id cannot be nil")

  if M.is_open() and M.instance.commit_info.commit_arg == commit_id then
    M.instance.buffer:win_exec(cmd)
  else
    M:close()
    local cw = api.nvim_get_current_win()
    M.new(commit_id, filter):open()
    api.nvim_set_current_win(cw)
  end
end

---@param commit_id string commit
---@param filter string[]? Filter diffs to filepaths in table
function M.open_or_scroll_down(commit_id, filter)
  M.open_or_run_in_window(commit_id, filter, "normal! " .. vim.keycode("<c-d>"))
end

---@param commit_id string commit
---@param filter string[]? Filter diffs to filepaths in table
function M.open_or_scroll_up(commit_id, filter)
  M.open_or_run_in_window(commit_id, filter, "normal! " .. vim.keycode("<c-u>"))
end

---@return boolean
function M.is_open()
  return (M.instance and M.instance.buffer and M.instance.buffer:is_visible()) == true
end

---Updates an already open buffer to show a new commit
---@param commit_id string commit
---@param filter string[]? Filter diffs to filepaths in table
function M:update(commit_id, filter)
  assert(commit_id, "commit id cannot be nil")

  local commit_info =
    git.log.parse(git.cli.show.format("fuller").args(commit_id).call({ trim = false }).stdout)[1]
  local commit_overview =
    parser.parse_commit_overview(git.cli.show.stat.oneline.args(commit_id).call({ hidden = true }).stdout)

  commit_info.commit_arg = commit_id

  self.item_filter = filter
  self.commit_info = commit_info
  self.commit_overview = commit_overview
  self.commit_signature = config.values.commit_view.verify_commit and git.log.verify_commit(commit_id) or {}

  self.buffer.ui:render(
    unpack(ui.CommitView(self.commit_info, self.commit_overview, self.commit_signature, self.item_filter))
  )

  self.buffer:win_call(vim.cmd, "normal! gg")
end

---Generate a callback to re-open CommitViewBuffer in the current commit
---@param self CommitViewBuffer
---@return fun()
local function get_reopen_cb(self)
  local original_cursor = api.nvim_win_get_cursor(0)
  local back_commit = self.commit_info.oid
  return function()
    M.new(back_commit):open()
    api.nvim_win_set_cursor(0, original_cursor)
  end
end

---@param self CommitViewBuffer
---@param location LocationInHunk
---@return string|nil, integer[]
local function location_to_commit_cursor(self, location)
  if string.sub(location.line, 1, 1) == "-" then
    return git.log.parent(self.commit_info.oid), { location.old, 0 }
  else
    return self.commit_info.oid, { location.new, 0 }
  end
end

---Visit the file at the location specified by the provided hunk component
---@param self CommitViewBuffer
---@param component Component A component that evaluates is_jumpable_hunk_line_component() to true
---@param worktree boolean if true, try to jump to the file in the current worktree. Otherwise jump to the file in the referenced commit
local function diff_visit_file(self, component, worktree)
  local hunk_component = component.parent.parent
  local hunk = hunk_component.options.hunk
  local path = vim.trim(hunk.file)
  if path == "" then
    notification.warn("Unable to determine file path for diff line")
    return
  end

  local line = self.buffer:cursor_line()
  local offset = line - hunk_component.position.row_start
  local location = jump.translate_hunk_location(hunk, offset)
  if not location then
    -- Cursor outside the hunk, shouldn't happen. Don't warn in that case
    return
  end

  if worktree then
    local cursor = { location.new, 0 }
    jump.goto_file_at(path, cursor)
  else
    local target_commit, cursor = location_to_commit_cursor(self, location)
    if not target_commit then
      notification.warn("Unable to retrieve parent commit")
      return nil, cursor
    end
    jump.goto_file_in_commit_at(target_commit, path, cursor, get_reopen_cb(self))
  end
end

---@param c Component
---@return boolean
local function is_jumpable_hunk_line_component(c)
  return c.options.line_hl == "NeogitDiffContext"
    or c.options.line_hl == "NeogitDiffAdd"
    or c.options.line_hl == "NeogitDiffDelete"
end

---@class ComponentAction Encapsulates an action to apply on a component only if the filter condition is met
---@field filter fun(c: Component) :boolean
---@field action fun(c: Component)

---Build a function to assign to a mapping given an array of ComponentAction
---@param actions_on_components ComponentAction[]
---@param component_getter fun(filter: fun(c: Component):boolean) : Component?
---@return fun()
local function filter_and_apply(actions_on_components, component_getter)
  return function()
    local applied_filter_index = nil
    local filter = function(c)
      for i, component_action in ipairs(actions_on_components) do
        if component_action.filter(c) then
          applied_filter_index = i
          return true
        end
      end
      return false
    end

    local c = component_getter(filter)
    if c and applied_filter_index ~= nil then
      actions_on_components[applied_filter_index].action(c)
    end
  end
end

---@param self CommitViewBuffer
---@param mappings table
---@return table
local function attach_jump_mappings(self, mappings)
  local special_mappings = {
    ["<cr>"] = {
      {
        filter = function(c)
          return c.options.highlight == "NeogitFilePath"
        end,
        action = function(c)
          -- Some paths are padded for formatting purposes. We need to trim them
          -- in order to use them as match patterns.
          local selected_path = vim.fn.trim(c.value)

          -- Recursively navigate the layout until we hit NeogitDiffHeader leaf nodes
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
            local path_norm = path
            for _, kind in ipairs { "modified", "renamed", "new file", "deleted file" } do
              if vim.startswith(path_norm, kind .. " ") then
                path_norm = string.sub(path_norm, string.len(kind) + 2)
                break
              end
            end
            -- The gsub is to work around the fact that the OverviewFiles use
            -- => in renames but the diff header uses ->
            path_norm = path_norm:gsub(" %-> ", " => ")

            if path_norm == selected_path then
              -- Save position in jumplist
              vim.cmd("normal! m'")

              self.buffer:move_cursor(line_nr)
              break
            end
          end
        end,
      },
    },
  }
  local open_file_maps = {
    [commit_view_maps["OpenFileInWorktree"][1]] = {
      filter = is_jumpable_hunk_line_component,
      action = function(c)
        diff_visit_file(self, c, true)
      end,
    },
    [commit_view_maps["OpenFileInCommit"][1]] = {
      filter = is_jumpable_hunk_line_component,
      action = function(c)
        diff_visit_file(self, c, false)
      end,
    },
  }
  for map, val in pairs(open_file_maps) do
    if special_mappings[map] == nil then
      special_mappings[map] = {}
    end
    table.insert(special_mappings[map], val)
  end
  for map, actions in pairs(special_mappings) do
    mappings.n[map] = filter_and_apply(actions, function(filter)
      return self.buffer.ui:get_component_under_cursor(filter)
    end)
  end
  return mappings
end

---Opens the CommitViewBuffer
---If already open will close the buffer
---@param kind? string
---@return CommitViewBuffer
function M:open(kind)
  kind = kind or config.values.commit_view.kind

  M.instance = self

  local mappings = {
    n = {
      ["o"] = function()
        if not vim.ui.open then
          notification.warn("Requires Neovim >= 0.10")
          return
        end

        local uri = git.remote.commit_url(self.commit_info.oid)
        if uri then
          notification.info(("Opening %q in your browser."):format(uri))
          vim.ui.open(uri)
        else
          notification.warn("Couldn't determine commit URL to open")
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
      [popups.mapping_for("BisectPopup")] = popups.open("bisect", function(p)
        p { commits = { self.commit_info.oid } }
      end),
      [popups.mapping_for("BranchPopup")] = popups.open("branch", function(p)
        p { commits = { self.commit_info.oid } }
      end),
      [popups.mapping_for("CherryPickPopup")] = popups.open("cherry_pick", function(p)
        p { commits = { self.commit_info.oid } }
      end),
      [popups.mapping_for("CommitPopup")] = popups.open("commit", function(p)
        p { commit = self.commit_info.oid }
      end),
      [popups.mapping_for("DiffPopup")] = popups.open("diff", function(p)
        p {
          section = { name = "log" },
          item = { name = self.commit_info.oid },
        }
      end),
      [popups.mapping_for("FetchPopup")] = popups.open("fetch"),
      -- help
      [popups.mapping_for("IgnorePopup")] = popups.open("ignore", function(p)
        local path = self.buffer.ui:get_hunk_or_filename_under_cursor()
        p {
          paths = { path and path.escaped_path },
          worktree_root = git.repo.worktree_root,
        }
      end),
      [popups.mapping_for("LogPopup")] = popups.open("log"),
      [popups.mapping_for("MergePopup")] = popups.open("merge", function(p)
        p { commit = self.buffer.ui:get_commit_under_cursor() }
      end),
      [popups.mapping_for("PullPopup")] = popups.open("pull"),
      [popups.mapping_for("PushPopup")] = popups.open("push", function(p)
        p { commit = self.commit_info.oid }
      end),
      [popups.mapping_for("RebasePopup")] = popups.open("rebase", function(p)
        p { commit = self.commit_info.oid }
      end),
      [popups.mapping_for("RemotePopup")] = popups.open("remote"),
      [popups.mapping_for("ResetPopup")] = popups.open("reset", function(p)
        p { commit = self.commit_info.oid }
      end),
      [popups.mapping_for("RevertPopup")] = popups.open("revert", function(p)
        local item = self.buffer.ui:get_hunk_or_filename_under_cursor() or {}
        p { commits = { self.commit_info.oid }, hunk = item.hunk }
      end),
      [popups.mapping_for("StashPopup")] = popups.open("stash"),
      [popups.mapping_for("TagPopup")] = popups.open("tag", function(p)
        p { commit = self.commit_info.oid }
      end),
      [popups.mapping_for("WorktreePopup")] = popups.open("worktree"),
      [status_maps["Close"]] = function()
        self:close()
      end,
      ["<esc>"] = function()
        self:close()
      end,
      [status_maps["YankSelected"]] = popups.open("yank", function(p)
        -- If the cursor is over a specific hunk, just copy that diff.
        local diff
        local c = self.buffer.ui:get_component_under_cursor(function(c)
          return c.options.hunk ~= nil
        end)

        if c then
          local hunks = util.flat_map(self.commit_info.diffs, function(diff)
            return diff.hunks
          end)

          for _, hunk in ipairs(hunks) do
            if hunk.hash == c.options.hunk.hash then
              diff = table.concat(util.merge({ hunk.line }, hunk.lines), "\n")
              break
            end
          end
        end

        -- If for some reason we don't find the specific hunk, or there isn't one, fall-back to the entire patch.
        if not diff then
          diff = table.concat(
            vim.tbl_map(function(diff)
              return table.concat(diff.lines, "\n")
            end, self.commit_info.diffs),
            "\n"
          )
        end

        p {
          hash = self.commit_info.oid,
          subject = self.commit_info.description[1],
          message = table.concat(self.commit_info.description, "\n"),
          body = table.concat(
            util.slice(self.commit_info.description, 2, #self.commit_info.description),
            "\n"
          ),
          url = git.remote.commit_url(self.commit_info.oid),
          diff = diff,
          author = ("%s <%s>"):format(self.commit_info.author_name, self.commit_info.author_email),
          tags = table.concat(git.tag.for_commit(self.commit_info.oid), ", "),
        }
      end),
      [status_maps["Toggle"]] = function()
        pcall(vim.cmd, "normal! za")
      end,
    },
  }
  mappings = attach_jump_mappings(self, mappings)

  self.buffer = Buffer.create {
    name = "NeogitCommitView",
    filetype = "NeogitCommitView",
    kind = kind,
    status_column = not config.values.disable_signs and "" or nil,
    context_highlight = not config.values.disable_context_highlighting,
    autocmds = {
      ["WinLeave"] = function()
        if self.buffer and self.buffer.kind == "floating" then
          self:close()
        end
      end,
    },
    mappings = mappings,
    render = function()
      return ui.CommitView(self.commit_info, self.commit_overview, self.commit_signature, self.item_filter)
    end,
    after = function()
      vim.cmd("normal! zR")
    end,
  }

  return self
end

return M
