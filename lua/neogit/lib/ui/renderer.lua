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
---@field current_line number
---@field current_column number
local Renderer = {}

function Renderer:new(namespace)
  local obj = {
    namespace = namespace,
    buffer = {
      line = {},
      highlight = {},
      line_highlight = {},
      extmark = {},
      fold = {},
    },
    flags = {
      in_row = false,
      in_nested_row = false,
    },
    curr_line = 1,
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

function Renderer:render(root)
  self:_render(0, root, root.children)

  return self.buffer
end

function Renderer:_render(first_col, parent, children)
  local col_start = first_col

  if self.flags.in_row then
    local col_end
    local highlights = {}
    local text = {}

    for i, c in ipairs(children) do
      col_start = self:_render_in_row_child(c, parent, i, col_start, col_end, highlights, text)
    end

    if self.flags.in_nested_row then
      return { text = table.concat(text), highlights = highlights }
    end

    table.insert(self.buffer.line, table.concat(text))

    for _, h in ipairs(highlights) do
      table.insert(self.buffer.highlight, { self.curr_line - 1, h.from, h.to, h.name })
    end

    self.curr_line = self.curr_line + 1
  else
    for i, c in ipairs(children) do
      self:_render_child(c, parent, i)
    end
  end
end

function Renderer:_render_in_row_child(child, parent, i, col_start, col_end, highlights, text)
  child.parent = parent
  child.index = i

  child.position = {}
  child.position.row_start = self.curr_line

  if child.tag == "text" then
    col_start = self:_render_in_row_text(child, i, col_start, highlights, text)
  elseif child.tag == "row" then
    col_start = self:_render_in_row_row(child, highlights, text, col_start, col_end)
  else
    error("The row component does not support having a `" .. child.tag .. "` as a child")
  end

  child.position.row_end = child.position.row_start

  return col_start
end

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
    table.insert(highlights, {
      from = col_start,
      to = col_end,
      name = highlight,
    })
  end

  return col_end
end

function Renderer:_render_child_text(child)
  table.insert(self.buffer.line, table.concat { child:get_padding_left(), child.value })

  local highlight = child:get_highlight()
  if highlight then
    table.insert(self.buffer.highlight, {
      self.curr_line - 1,
      child.position.col_start,
      child.position.col_end,
      highlight,
    })
  end

  local line_hl = child:get_line_highlight()
  if line_hl then
    table.insert(self.buffer.line_highlight, { self.curr_line - 1, line_hl })
  end

  self.curr_line = self.curr_line + 1
end

function Renderer:_render_child(child, parent, i)
  child.parent = parent
  child.index = i

  child.position = {}
  child.position.row_start = self.curr_line
  child.position.col_start = 0
  child.position.col_end = -1

  if child.tag == "text" then
    self:_render_child_text(child)
  elseif child.tag == "col" then
    self:_render(0, child, child.children)
  elseif child.tag == "row" then
    self:_render_child_row(child)
  end

  child.position.row_end = self.curr_line - 1

  if child.options.foldable then
    table.insert(self.buffer.fold, {
      #self.buffer.line - (child.position.row_end - child.position.row_start),
      #self.buffer.line,
      not child.options.folded,
    })
  end
end

function Renderer:_render_in_row_row(child, highlights, text, col_start, col_end)
  self.flags.in_nested_row = true
  local res = self:_render(col_start, child, child.children)
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

function Renderer:_render_child_row(child)
  self.flags.in_row = true
  self:_render(0, child, child.children)
  self.flags.in_row = false

  local line_hl = child:get_line_highlight()
  if line_hl then
    table.insert(self.buffer.line_highlight, { self.curr_line - 2, line_hl })
  end

  if child.options.virtual_text then
    table.insert(self.buffer.extmark, {
      self.namespace,
      self.curr_line - 2,
      0,
      {
        hl_mode = "combine",
        virt_text = child.options.virtual_text,
        virt_text_pos = "right_align",
      },
    })
  end
end

return Renderer
