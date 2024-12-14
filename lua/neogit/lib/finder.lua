local config = require("neogit.config")
local a = require("plenary.async")

local function refocus_status_buffer()
  local status = require("neogit.buffers.status")
  if status.instance() then
    status.instance():focus()
    status.instance():dispatch_refresh(nil, "finder.refocus")
  end
end

local function telescope_mappings(on_select, allow_multi, refocus_status)
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")

  local function close_action(prompt_bufnr)
    actions.close(prompt_bufnr)

    if refocus_status then
      refocus_status_buffer()
    end
  end

  --- Lift the picker select action to a item select action
  local function select_action(prompt_bufnr)
    local selection = {}

    local picker = action_state.get_current_picker(prompt_bufnr)
    if #picker:get_multi_selection() > 0 then
      for _, item in ipairs(picker:get_multi_selection()) do
        table.insert(selection, item[1])
      end
    elseif action_state.get_selected_entry() ~= nil then
      local entry = action_state.get_selected_entry()[1]
      local prompt = picker:_get_prompt()

      local navigate_up_level = entry == ".." and #prompt > 0
      local input_git_refspec = prompt:match("%^")
        or prompt:match("~")
        or prompt:match("@")
        or prompt:match(":")

      if navigate_up_level or input_git_refspec then
        table.insert(selection, prompt)
      else
        table.insert(selection, entry)
      end
    else
      table.insert(selection, picker:_get_prompt())
    end

    if not selection[1] or selection[1] == "" then
      return
    end

    close_action(prompt_bufnr)

    if allow_multi then
      on_select(selection)
    else
      on_select(selection[1])
    end
  end

  local function close(...)
    -- Make sure to notify the caller that we aborted to avoid hanging on the async task forever
    on_select(nil)
    close_action(...)
  end

  local function completion_action(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)
    -- selene: allow(empty_if)
    if #picker:get_multi_selection() > 0 then
      -- Don't autocomplete with multiple selection
    elseif action_state.get_selected_entry() ~= nil then
      picker:set_prompt(action_state.get_selected_entry()[1])
    end
  end

  return function(_, map)
    local commands = {
      ["Select"] = select_action,
      ["Close"] = close,
      ["InsertCompletion"] = completion_action,
      ["Next"] = actions.move_selection_next,
      ["Previous"] = actions.move_selection_previous,
      ["NOP"] = actions.nop,
      ["MultiselectToggleNext"] = actions.toggle_selection + actions.move_selection_worse,
      ["MultiselectTogglePrevious"] = actions.toggle_selection + actions.move_selection_better,
      ["MultiselectToggle"] = actions.toggle_selection,
    }

    -- Telescope HEAD has mouse click support, but not the latest tag. Need to check if the user has
    -- support for mouse click, while avoiding the error that the metatable raises.
    -- stylua: ignore
    if pcall(function() return actions.mouse_click and true end) then
      commands.ScrollWheelDown = actions.move_selection_next
      commands.ScrollWheelUp = actions.move_selection_previous
      commands.MouseClick = actions.mouse_click
    end

    for mapping, command in pairs(config.values.mappings.finder) do
      if command and command:match("^Multiselect") then
        if allow_multi then
          map({ "i" }, mapping, commands[command])
        end
      elseif command then
        map({ "i" }, mapping, commands[command])
      end
    end

    return false
  end
end

--- Utility function to map actions
---@param on_select fun(item: any|nil)
---@param allow_multi boolean
---@param refocus_status boolean
local function fzf_actions(on_select, allow_multi, refocus_status)
  local function refresh()
    if refocus_status then
      refocus_status_buffer()
    end
  end

  local function close_action()
    on_select(nil)
    refresh()
  end

  return {
    ["default"] = function(selected)
      if allow_multi then
        on_select(selected)
      else
        on_select(selected[1])
      end
      refresh()
    end,
    ["esc"] = close_action,
    ["ctrl-c"] = close_action,
    ["ctrl-q"] = close_action,
  }
end

--- Utility function to map finder opts to fzf
---@param opts FinderOpts
---@return table
local function fzf_opts(opts)
  local fzf_opts = {}

  -- Allow multi by default
  if opts.allow_multi then
    fzf_opts["--multi"] = ""
  else
    fzf_opts["--no-multi"] = ""
  end

  if opts.layout_config.prompt_position ~= "top" then
    fzf_opts["--layout"] = "reverse-list"
  end

  if opts.border then
    fzf_opts["--border"] = "rounded"
  else
    fzf_opts["--border"] = "none"
  end

  return fzf_opts
end

---@return FinderOpts
local function default_opts()
  return {
    layout_config = {
      height = 0.3,
      prompt_position = "top",
      preview_cutoff = vim.fn.winwidth(0),
    },
    refocus_status = true,
    allow_multi = false,
    border = false,
    prompt_prefix = "select",
    previewer = false,
    cache_picker = false,
    layout_strategy = "bottom_pane",
    sorting_strategy = "ascending",
    theme = "ivy",
  }
end

---@class FinderOpts
---@field layout_config table
---@field allow_multi boolean
---@field border boolean
---@field prompt_prefix string
---@field previewer boolean
---@field layout_strategy string
---@field sorting_strategy string
---@field theme string

---@class Finder
---@field opts table
---@field entries table
---@field mappings function|nil
local Finder = {}
Finder.__index = Finder

---@param opts FinderOpts
---@return Finder
function Finder:new(opts)
  local this = {
    opts = vim.tbl_deep_extend("keep", opts, default_opts()),
    entries = {},
    select_action = nil,
  }

  setmetatable(this, self)

  return this
end

---Adds entries to internal table
---@param entries table
---@return Finder
function Finder:add_entries(entries)
  for _, entry in ipairs(entries) do
    table.insert(self.entries, entry)
  end
  return self
end

---Engages finder and invokes `on_select` with the item or items, or nil if aborted
---@param on_select fun(item: any|nil)
function Finder:find(on_select)
  if config.check_integration("telescope") then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local sorters = require("telescope.sorters")

    self.opts.prompt_prefix = string.format(" %s > ", self.opts.prompt_prefix)

    local default_sorter
    local native_sorter = function()
      local fzf_extension = require("telescope").extensions.fzf
      if fzf_extension then
        default_sorter = fzf_extension.native_fzf_sorter()
      end
    end

    if not pcall(native_sorter) then
      default_sorter = sorters.get_generic_fuzzy_sorter()
    end

    pickers
      .new(self.opts, {
        finder = finders.new_table { results = self.entries },
        sorter = config.values.telescope_sorter() or default_sorter,
        attach_mappings = telescope_mappings(on_select, self.opts.allow_multi, self.opts.refocus_status),
      })
      :find()
  elseif config.check_integration("fzf_lua") then
    local fzf_lua = require("fzf-lua")
    fzf_lua.fzf_exec(self.entries, {
      prompt = string.format("%s> ", self.opts.prompt_prefix),
      fzf_opts = fzf_opts(self.opts),
      winopts = {
        height = self.opts.layout_config.height,
      },
      actions = fzf_actions(on_select, self.opts.allow_multi, self.opts.refocus_status),
    })
  elseif config.check_integration("mini_pick") then
    local mini_pick = require("mini.pick")
    mini_pick.start { source = { items = self.entries, choose = on_select } }
  else
    vim.ui.select(self.entries, {
      prompt = string.format("%s: ", self.opts.prompt_prefix),
      format_item = function(entry)
        return entry
      end,
    }, function(item)
      vim.schedule(function()
        on_select(self.opts.allow_multi and { item } or item)

        if self.opts.refocus_status then
          refocus_status_buffer()
        end
      end)
    end)
  end
end

---@type async fun(self: Finder): any|nil
--- Asynchronously prompt the user for the selection, and return the selected item or nil if aborted.
Finder.find_async = a.wrap(Finder.find, 2)

---Builds Finder instance
---@param opts table|nil
---@return Finder
function Finder.create(opts)
  return Finder:new(opts or {})
end

--- Example usage
function Finder.test()
  a.run(function()
    local f = Finder:create()
    f:add_entries { "a", "b", "c" }

    local item = f:find_async()

    if item then
      print("Got item: ", vim.inspect(item))
    else
      print("Aborted")
    end
  end)
end

return Finder
