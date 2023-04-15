local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")

local function mappings(select_action, allow_multi)
  return function(_, map)
    map({ "i" }, "<cr>", select_action)
    map({ "i" }, "<C-c>", actions.close)
    map({ "i" }, "<C-n>", actions.move_selection_next)
    map({ "i" }, "<C-p>", actions.move_selection_previous)
    map({ "i" }, "<esc>", actions.close)
    map({ "i" }, "<down>", actions.move_selection_next)
    map({ "i" }, "<up>", actions.move_selection_previous)
    map({ "i" }, "<C-j>", actions.nop)

    if allow_multi then
      map({ "i" }, "<tab>", actions.toggle_selection + actions.move_selection_worse)
      map({ "i" }, "<s-tab>", actions.toggle_selection + actions.move_selection_better)
    end

    return false
  end
end

local function default_opts()
  return {
    layout_config = {
      height = 0.3,
      prompt_position = "top",
      preview_cutoff = vim.fn.winwidth(0),
    },
    allow_multi = false,
    border = false,
    prompt_prefix = " > ",
    previewer = false,
    layout_strategy = "bottom_pane",
    sorting_strategy = "ascending",
    theme = "ivy",
  }
end

---@class Finder
---@field opts table
---@field entries table
---@field mappings function|nil
local Finder = {}
Finder.__index = Finder

---@param opts table
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

---Adds a select action - NOT OPTIONAL
---@param action function
---@return Finder
function Finder:add_select_action(action)
  self.select_action = action
  return self
end

---Engages finder
function Finder:find()
  pickers
    .new(self.opts, {
      finder = finders.new_table { results = self.entries },
      sorter = sorters.fuzzy_with_index_bias(),
      attach_mappings = mappings(self.select_action, self.opts.allow_multi),
    })
    :find()
end

---Builds Finder instance
---@param opts table|nil
---@return Finder
function Finder.create(opts)
  return Finder:new(opts or {})
end

return Finder
