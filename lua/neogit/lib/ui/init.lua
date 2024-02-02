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

---@param fn fun(c: Component): boolean
---@return Component|nil
function Ui:get_component_under_cursor(fn)
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

function Ui:get_fold_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)

  return self:_find_component_by_index(cursor[1], function(node)
    return node.options.foldable
  end)
end

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

---@return string|nil
function Ui:get_current_section()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local component = self:_find_component_by_index(cursor[1], function(node)
    return node.options.section
  end)

  return component and component.options.section
end

---@return table|nil
function Ui:get_hunk_or_filename_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local component = self:_find_component_by_index(cursor[1], function(node)
    return node.options.hunk or node.options.filename
  end)

  return component and {
    hunk = component.options.hunk,
    filename = component.options.filename
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

function Ui:render(...)
  self.layout = { ... }
  self.layout = util.filter(self.layout, function(x)
    return type(x) == "table"
  end)

  self:update()
end

-- This shouldn't be called often as it completely rewrites the whole buffer
function Ui:update()
  local ns = self.buf:create_namespace("VirtualText")
  local buffer, index = Renderer:new(ns):render(self.layout)

  self.node_index = index
  local cursor_line = self.buf:cursor_line()

  self.buf:unlock()
  self.buf:clear()
  self.buf:clear_namespace("default")
  self.buf:resize(#buffer.line)
  self.buf:set_lines(0, -1, false, buffer.line)
  self.buf:set_highlights(buffer.highlight)
  self.buf:set_extmarks(buffer.extmark)
  self.buf:set_line_highlights(buffer.line_highlight)
  self.buf:set_folds(buffer.fold)
  self.buf:lock()

  self.buf:move_cursor(cursor_line)
end

Ui.col = Component.new(function(children, options)
  return {
    tag = "col",
    children = util.filter(children, function(x)
      return type(x) == "table"
    end),
    options = options,
  }
end)

Ui.row = Component.new(function(children, options)
  return {
    tag = "row",
    children = util.filter(children, function(x)
      return type(x) == "table"
    end),
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
