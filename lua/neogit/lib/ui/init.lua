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
function Ui:get_cursor_context(line)
  local cursor = line or vim.api.nvim_win_get_cursor(0)[1]
  return self:_find_component_by_index(cursor, function(node)
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

---@return table
function Ui:get_hunks_and_filenames_in_selection()
  local range = { vim.fn.getpos("v")[2], vim.fn.getpos(".")[2] }
  table.sort(range)
  local start, stop = unpack(range)

  local items = {
    hunks = {
      untracked = {},
      unstaged = {},
      staged = {}
    },
    files = {
      untracked = {},
      unstaged = {},
      staged = {}
    },
  }

  for i = start, stop do
    local section = self:get_current_section(i)

    local component = self:_find_component_by_index(i, function(node)
      return node.options.hunk or node.options.filename
    end)

    if component and section then
      section = section.options.section

      if component.options.hunk then
        table.insert(items.hunks[section], component.options.hunk)
      elseif component.options.filename then
        table.insert(items.files[section], component.options.item)
      end
    end
  end

  return items
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
function Ui:get_current_section(line)
  line = line or vim.api.nvim_win_get_cursor(0)[1]
  local component = self:_find_component_by_index(line, function(node)
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

local function node_prefix(node, prefix)
  local base = false
  local key
  if node.options.section then
    key = node.options.section
  elseif node.options.filename then
    key = node.options.filename
  elseif node.options.hunk then
    base = true
    key = node.options.hunk.hash
  end

  if key then
    return ("%s--%s"):format(prefix, key), base
  else
    return nil, base
  end
end

local function gather_nodes(node, node_table, prefix)
  if not node_table then
    node_table = {}
  end

  prefix = prefix or ""

  local key, base = node_prefix(node, prefix)
  if key then
    prefix = key
    node_table[prefix] = { folded = node.options.folded }
  end

  if node.children and not base then
    for _, child in ipairs(node.children) do
      gather_nodes(child, node_table, prefix)
    end
  end

  return node_table
end

function Ui:_update_attributes(node, attributes, prefix)
  prefix = prefix or ""

  local key, base = node_prefix(node, prefix)
  if key then
    prefix = key

    -- TODO: If a hunk is closed, it will be re-opened on update because the on_open callback runs async :\
    if attributes[prefix] then
      if node.options.on_open and not attributes[prefix].folded then
        node.options.on_open(node, self, prefix)
      end

      node.options.folded = attributes[prefix].folded
    end
  end

  if node.children and not base then
    for _, child in ipairs(node.children) do
      self:_update_attributes(child, attributes, prefix)
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

    -- Restoring cursor location for status buffer on update. Might need to move this, as it doesn't really make sense
    -- here.
    local context = self:get_cursor_context()
    if context then
      if context.options.tag == "Hunk" then
        if context.index == 1 then
          if #context.parent.children > 1 then
            self._cursor_context_start = ({ context:row_range_abs() })[1]
          else
            self._cursor_context_start = ({ context:row_range_abs() })[1] - 1
          end
        else
          self._cursor_context_start = ({ context.parent.children[context.index - 1]:row_range_abs() })[1]
        end
      elseif context.options.tag == "File" then
        if context.index == 1 then
          if #context.parent.children > 1 then
            -- id is scoped by section. Advance to next file.
            self._cursor_goto = context.parent.children[2].options.id
          else
            -- Yankable lets us jump from one section to the other. Go to same file in new section.
            self._cursor_goto = context.options.yankable
          end
        else
          self._cursor_goto = context.parent.children[context.index - 1].options.id
        end
      else
      end
    end
  end

  self.layout = root
  self:update()
end

function Ui:update()
  -- If the buffer is not focused, trying to set folds will raise an error because it's not a proper API.
  if not self.buf:is_focused() then
    return
  end

  local renderer = Renderer:new(self.layout, self.buf):render()
  self.node_index = renderer:node_index()

  local cursor_line = self.buf:cursor_line()

  self.buf:unlock()
  self.buf:clear()
  self.buf:clear_namespace("default")
  self.buf:clear_namespace("ViewContext")
  self.buf:resize(#renderer.buffer.line)
  self.buf:set_lines(0, -1, false, renderer.buffer.line)
  self.buf:set_highlights(renderer.buffer.highlight)
  self.buf:set_extmarks(renderer.buffer.extmark)
  self.buf:set_line_highlights(renderer.buffer.line_highlight)
  self.buf:set_folds(renderer.buffer.fold)
  self.buf:lock()

  if self._old_node_attributes then
    self:_update_attributes(self.layout, self._old_node_attributes)
    self._old_node_attributes = nil
  end

  if self._cursor_context_start then
    self.buf:move_cursor(self._cursor_context_start)
    self._cursor_context_start = nil
  elseif self._cursor_goto then
    if self.node_index:find_by_id(self._cursor_goto) then
      self.buf:move_cursor(self.node_index:find_by_id(self._cursor_goto):row_range_abs())
    end

    self._cursor_goto = nil
  else
    self.buf:move_cursor(cursor_line)
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
