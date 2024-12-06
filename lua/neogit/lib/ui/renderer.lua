---@source component.lua

---@class RendererIndex
---@field index table
---@field items table
---@field oid_index table
local RendererIndex = {}
RendererIndex.__index = RendererIndex

---@param line number
---@return Component[]
function RendererIndex:find_by_line(line)
  return self.index[line] or {}
end

---@param oid string
---@return Component|nil
function RendererIndex:find_by_oid(oid)
  return self.oid_index[oid]
end

---@param node Component
function RendererIndex:add(node)
  if not self.index[node.position.row_start] then
    self.index[node.position.row_start] = {}
  end

  table.insert(self.index[node.position.row_start], node)
end

---For tracking item locations within status buffer. Needed to make selections.
---@param name string
---@param first number
---@param last number
function RendererIndex:add_section(name, first, last)
  self.items[#self.items].name = name
  self.items[#self.items].first = first
  self.items[#self.items].last = last
  table.insert(self.items, { items = {} })
end

function RendererIndex:add_item(item, first, last)
  self.items[#self.items].last = last

  item.first = first
  item.last = last
  table.insert(self.items[#self.items].items, item)

  if item.oid then
    self.oid_index[item.oid] = item
  end
end

function RendererIndex.new()
  return setmetatable({
    index = {},
    oid_index = {},
    items = {
      { items = {} }, -- First section
    },
  }, RendererIndex)
end

---@class RendererBuffer
---@field line string[]
---@field highlight table[]
---@field line_highlight table[]
---@field extmark table[]
---@field fold table[]

---@class RendererFlags
---@field in_row boolean
---@field in_nested_row boolean

---@class Renderer
---@field buffer RendererBuffer
---@field flags RendererFlags
---@field namespace integer
---@field layout table
---@field current_column number
---@field index table
local Renderer = {}
Renderer.__index = Renderer

---@param layout table
---@param buffer Buffer
---@return Renderer
function Renderer:new(layout, buffer)
  local obj = {
    namespace = buffer:create_namespace("VirtualText"),
    layout = layout,
    buffer = {
      line = {},
      highlight = {},
      line_highlight = {},
      extmark = {},
      fold = {},
    },
    index = RendererIndex.new(),
    flags = {
      in_row = false,
      in_nested_row = false,
    },
  }

  setmetatable(obj, self)

  return obj
end

---@return Renderer
function Renderer:render()
  self:_render(self.layout, self.layout.children, 0)

  return self
end

---@return RendererIndex
function Renderer:node_index()
  return self.index
end

---@return RendererIndex
function Renderer:item_index()
  return self.index.items
end

function Renderer:_build_child(child, parent, index)
  child.parent = parent
  child.index = index
  child.position = {
    row_start = #self.buffer.line + 1,
    row_end = self.flags.in_row and #self.buffer.line + 1 or -1,
    col_start = 0,
    col_end = -1,
  }
end

---@param parent Component
---@param children Component[]
---@param column integer
function Renderer:_render(parent, children, column)
  if self.flags.in_row then
    local col_start = column
    local col_end
    local highlights = {}
    local text = {}

    for index, child in ipairs(children) do
      self:_build_child(child, parent, index)
      col_start = self:_render_child_in_row(child, index, col_start, col_end, highlights, text)
    end

    if self.flags.in_nested_row then
      return { text = table.concat(text), highlights = highlights }
    end

    table.insert(self.buffer.line, table.concat(text))

    for _, h in ipairs(highlights) do
      table.insert(self.buffer.highlight, { #self.buffer.line - 1, h.from, h.to, h.name })
    end
  else
    for index, child in ipairs(children) do
      self:_build_child(child, parent, index)
      self:_render_child(child)
    end
  end
end

---@param child Component
function Renderer:_render_child(child)
  if child.tag == "text" then
    self:_render_text(child)
  elseif child.tag == "col" then
    self:_render_col(child)
  elseif child.tag == "row" then
    self:_render_row(child)
  end

  child.position.row_end = #self.buffer.line

  if child.options.section then
    self.index:add_section(child.options.section, child.position.row_start, child.position.row_end)
  end

  if child.options.item then
    child.options.item.folded = child.options.folded
    self.index:add_item(child.options.item, child.position.row_start, child.position.row_end)
  end

  local line_hl = child:get_line_highlight()
  if line_hl then
    table.insert(self.buffer.line_highlight, { #self.buffer.line - 1, line_hl })
  end

  if child.options.virtual_text then
    table.insert(self.buffer.extmark, {
      self.namespace,
      #self.buffer.line - 1,
      0,
      {
        hl_mode = "combine",
        virt_text = child.options.virtual_text,
        virt_text_pos = "right_align",
      },
    })
  end

  if child.options.foldable then
    table.insert(self.buffer.fold, {
      #self.buffer.line - (child.position.row_end - child.position.row_start),
      #self.buffer.line,
      not child.options.folded,
      child.options.tag,
    })
  end
end

---@param child Component
function Renderer:_render_row(child)
  self.flags.in_row = true
  self:_render(child, child.children, 0)
  self.flags.in_row = false
end

---@param child Component
function Renderer:_render_col(child)
  self:_render(child, child.children, 0)
end

---@param child Component
function Renderer:_render_text(child)
  local highlight = child:get_highlight()
  if highlight then
    table.insert(self.buffer.highlight, {
      #self.buffer.line,
      child.position.col_start,
      child.position.col_end,
      highlight,
    })
  end

  local line_highlight = child:get_line_highlight()
  if line_highlight then
    table.insert(self.buffer.line_highlight, { #self.buffer.line, line_highlight })
  end

  table.insert(self.buffer.line, table.concat { child:get_padding_left(), child.value })
  self.index:add(child)
end

---@param child Component
---@param i integer index of child in parent.children
function Renderer:_render_child_in_row(child, i, col_start, col_end, highlights, text)
  if child.tag == "text" then
    return self:_render_in_row_text(child, i, col_start, highlights, text)
  elseif child.tag == "row" then
    return self:_render_in_row_row(child, highlights, text, col_start, col_end)
  else
    error("The row component does not support having a `" .. child.tag .. "` as a child")
  end
end

---@param child Component
---@param index integer index of child in parent.children
function Renderer:_render_in_row_text(child, index, col_start, highlights, text)
  local padding_left = self.flags.in_nested_row and "" or child:get_padding_left(index == 1)
  table.insert(text, 1, padding_left)

  col_start = col_start + #padding_left
  local col_end = col_start + child:get_width()

  child.position.col_start = col_start
  child.position.col_end = col_end - 1

  if child.options.align_right then
    table.insert(text, child.value)
    table.insert(text, (" "):rep(child.options.align_right - #child.value))
  else
    table.insert(text, child.value)
  end

  local highlight = child:get_highlight()
  if highlight then
    table.insert(highlights, { from = col_start, to = col_end, name = highlight })
  end

  self.index:add(child)
  return col_end
end

---@param child Component
function Renderer:_render_in_row_row(child, highlights, text, col_start, col_end)
  self.flags.in_nested_row = true
  local res = self:_render(child, child.children, col_start)
  self.flags.in_nested_row = false

  table.insert(text, res.text)

  for _, h in ipairs(res.highlights) do
    table.insert(highlights, h)
  end

  col_end = col_start + vim.fn.strdisplaywidth(res.text)
  child.position.col_start = col_start
  child.position.col_end = col_end

  return col_end
end

return Renderer
