local Component = require("neogit.lib.ui.component")
local util = require("neogit.lib.util")
local Renderer = require("neogit.lib.ui.renderer")

---@class UiComponent
---@field tag string
---@field options table Component props or arguments
---@field children UiComponent[]

---@class FindOptions

---@class Ui
---@field buf Buffer
---@field layout table
local Ui = {}
Ui.__index = Ui

---@param buf Buffer
---@return Ui
function Ui.new(buf)
  return setmetatable({ buf = buf, layout = {} }, Ui)
end

function Ui._find_component(components, f, options)
  for _, c in ipairs(components) do
    if c.tag == "col" or c.tag == "row" then
      local res = Ui._find_component(c.children, f, options)

      if res then
        return res
      end
    end

    if f(c) then
      return c
    end
  end

  return nil
end

---@param f fun(c: UiComponent): boolean
---@param options FindOptions|nil
function Ui:find_component(f, options)
  return Ui._find_component(self.layout, f, options or {})
end

function Ui._find_components(components, f, result, options)
  for _, c in ipairs(components) do
    if c.tag == "col" or c.tag == "row" then
      Ui._find_components(c.children, f, result, options)
    end

    if f(c) then
      table.insert(result, c)
    end
  end
end

function Ui:find_components(f, options)
  local result = {}
  Ui._find_components(self.layout, f, result, options or {})
  return result
end

---@param fn? fun(c: Component): boolean
---@return Component|nil
function Ui:get_component_under_cursor(fn)
  fn = fn or function()
    return true
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  return self:get_component_on_line(line, fn)
end

---@param line integer
---@param fn fun(c: Component): boolean
---@return Component|nil
function Ui:get_component_on_line(line, fn)
  return self:_find_component_by_index(line, fn)
end

---@param line integer
---@param f fun(c: Component): boolean
---@return Component|nil
function Ui:_find_component_by_index(line, f)
  local node = self.node_index:find_by_line(line)[1]
  while node do
    if f(node) then
      return node
    end

    node = node.parent
  end
end

---@return Component|nil
function Ui:find_by_id(id)
  return self.node_index:find_by_id(id)
end

---@return Component|nil
function Ui:get_cursor_context()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return self:_find_component_by_index(cursor[1], function(node)
    return node.options.context
  end)
end

---@return string|nil
function Ui:get_line_highlight(line)
  local component = self:_find_component_by_index(line, function(node)
    return node.options.line_hl ~= nil
  end)

  return component and component.options.line_hl
end

---@return Component|nil
function Ui:get_interactive_component_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)

  return self:_find_component_by_index(cursor[1], function(node)
    return node.options.interactive
  end)
end

---@return Component|nil
function Ui:get_fold_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)

  return self:_find_component_by_index(cursor[1], function(node)
    return node.options.foldable
  end)
end

---@return string[]
function Ui:get_commits_in_selection()
  local range = { vim.fn.getpos("v")[2], vim.fn.getpos(".")[2] }
  table.sort(range)
  local start, stop = unpack(range)

  local commits = {}
  for i = start, stop do
    local component = self:_find_component_by_index(i, function(node)
      return node.options.oid
    end)

    if component then
      table.insert(commits, 1, component.options.oid)
    end
  end

  return util.deduplicate(commits)
end

---@return string|nil
function Ui:get_commit_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local component = self:_find_component_by_index(cursor[1], function(node)
    return node.options.oid
  end)

  return component and component.options.oid
end

---@return string|nil
function Ui:get_yankable_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local component = self:_find_component_by_index(cursor[1], function(node)
    return node.options.yankable
  end)

  return component and component.options.yankable
end

---@return Component|nil
function Ui:get_current_section()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local component = self:_find_component_by_index(cursor[1], function(node)
    return node.options.section
  end)

  return component
end

---@return table|nil
function Ui:get_hunk_or_filename_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local component = self:_find_component_by_index(cursor[1], function(node)
    return node.options.hunk or node.options.filename
  end)

  return component and {
    hunk = component.options.hunk,
    filename = component.options.filename,
  }
end

---@return table|nil
function Ui:get_item_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local component = self:_find_component_by_index(cursor[1], function(node)
    return node.options.item
  end)

  return component and component.options.item
end

---@param layout table
---@return table[]
local function filter_layout(layout)
  return util.filter(layout, function(x)
    return type(x) == "table"
  end)
end

---@param old table
---@param new table
local function compare_trees(old, new)
  if old == nil or new == nil then
    return false
  end

  if old == new then
    return true
  end

  if old.children and new.children then
    for i = 1, #old.children do
      if not compare_trees(old.children[i], new.children[i]) then
        if old.children[i] and new.children[i] then
          -- P({ old = old.children[i].options, new = new.children[i].options })

          if not old.children[i].tag == "Section" and not new.children[i].tag == "Section" then
            old.children[i] = new.children[i]
          end
        end

        return false
      end
    end
  end

  return true
end

function Ui:render(...)
  local layout = filter_layout { ... }
  local root = Component.new(function()
    return { tag = "_root", children = layout }
  end)()

  if vim.tbl_isempty(self.layout) then
    self.layout = root
  else
    -- This is hard.
    compare_trees(self.layout, root)
  end

  self:update()
end

function Ui:update()
  local renderer = Renderer:new(self.layout, self.buf):render()
  self.node_index = renderer:node_index()
end

Ui.col = Component.new(function(children, options)
  return {
    tag = "col",
    children = filter_layout(children),
    options = options,
  }
end)

Ui.row = Component.new(function(children, options)
  return {
    tag = "row",
    children = filter_layout(children),
    options = options,
  }
end)

Ui.text = Component.new(function(value, options, ...)
  if ... then
    error("Too many arguments")
  end

  vim.validate {
    options = { options, "table", true },
  }

  return {
    tag = "text",
    value = value or "",
    options = type(options) == "table" and options or nil,
    __index = {
      render = function(self)
        return self.value
      end,
    },
  }
end)

Ui.Component = Component

return Ui
