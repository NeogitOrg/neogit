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

local function gather_nodes(node, node_table, prefix)
  if not node_table then
    node_table = {}
  end

  prefix = prefix or ""

  if node.options.section then
    node_table[node.options.section] = {
      folded = node.options.folded,
    }

    if node.children then
      for _, child in ipairs(node.children) do
        gather_nodes(child, node_table, node.options.section)
      end
    end
  else
    if node.options.filename then
      local key = ("%s--%s"):format(prefix, node.options.filename)
      node_table[key] = {
        folded = node.options.folded,
      }

      for _, child in ipairs(node.children) do
        gather_nodes(child, node_table, key)
      end
    elseif node.options.hunk then
      local key = ("%s--%s"):format(prefix, node.options.hunk.hash)
      node_table[key] = { folded = node.options.folded }
    elseif node.children then
      for _, child in ipairs(node.children) do
        gather_nodes(child, node_table, prefix)
      end
    end
  end

  return node_table
end

function Ui:_update_attributes(node, attributes, prefix)
  prefix = prefix or ""

  if node.options.section then
    if attributes[node.options.section] then
      node.options.folded = attributes[node.options.section].folded
    end

    if node.children then
      for _, child in ipairs(node.children) do
        self:_update_attributes(child, attributes, node.options.section)
      end
    end
  else
    if node.options.filename then
      local key = ("%s--%s"):format(prefix, node.options.filename)
      if attributes[key] and not attributes[key].folded then
        if node.options.on_open then
          node.options.on_open(node, self)
        end
      end

      for _, child in ipairs(node.children) do
        self:_update_attributes(child, attributes, key)
      end
    elseif node.options.hunk then
      local key = ("%s--%s"):format(prefix, node.options.hunk.hash)
      if attributes[key] then
        node.options.folded = attributes[key].folded
      end
    elseif node.children then
      for _, child in ipairs(node.children) do
        self:_update_attributes(child, attributes, prefix)
      end
    end
  end
end

function Ui:render(...)
  local layout = filter_layout { ... }
  local root = Component.new(function()
    return { tag = "_root", children = layout }
  end)()

  if not vim.tbl_isempty(self.layout) then
    self._old_node_attributes = gather_nodes(self.layout)
  end

  self.layout = root
  self:update()
end

function Ui:update()
  local renderer = Renderer:new(self.layout, self.buf):render()
  self.node_index = renderer:node_index()

  if self._old_node_attributes then
    self:_update_attributes(self.layout, self._old_node_attributes)
    self._old_node_attributes = nil
  end
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
