local Buffer = require 'neogit.lib.buffer'
local Ui = {}

function Ui.new(buf)
  local this = { 
    buf = buf,
    layout = {}
  }
  setmetatable(this, { __index = Ui })
  return this
end

function Ui._visualize_tree(indent, components)
  for _, c in ipairs(components) do
    local output = string.rep("  ", indent) .. c.tag
    if c.tag == "text" then
      output = output .. " '" .. c.value .. "'"
    end
    print(output)
    if c.tag == "col" or c.tag == "row" then
      Ui._visualize_tree(indent + 1, c.children)
    end
  end
end

function Ui.visualize_tree(components)
  print("root")
  Ui._visualize_tree(1, components)
end

function Ui:_render(first_line, components, flags)
  local curr_line = first_line
  
  if flags.in_row then
    local col_start = 0
    local col_end
    local highlights = {}
    local sign = nil
    local text = ""

    for i, c in ipairs(components) do
      if c.tag == "text" then
        col_end = col_start + #c.value
        text = text .. c.value
        if c.options.highlight then
          table.insert(highlights, {
            from = col_start,
            to = col_end,
            name = c.options.highlight
          })
        end
        if c.options.sign then
          sign = c.options.sign
        end
        col_start = col_end
      else
        error("The row component does not support having a `" .. c.tag .. "` as child")
      end
    end

    self.buf:set_lines(curr_line, curr_line + 1, false, { text })

    for _, h in ipairs(highlights) do
      self.buf:add_highlight(curr_line, h.from, h.to, h.name, 0)
    end

    if sign then
      self.buf:place_sign(curr_line, sign, "hl")
    end

    curr_line = curr_line + 1
  else
    for i, c in ipairs(components) do
      if c.tag == "text" then
        self.buf:set_lines(curr_line, curr_line + 1, false, { c.value })
        curr_line = curr_line + 1
        if c.options.highlight then
          self.buf:add_highlight(curr_line - 1, 0, -1, c.options.highlight, 0)
        end
        if c.options.sign then
          self.buf:place_sign(curr_line, c.options.sign, "hl")
        end
      elseif c.tag == "col" then
        curr_line = curr_line + self:_render(curr_line, c.children, flags)
      elseif c.tag == "row" then
        flags.in_row = true
        curr_line = curr_line + self:_render(curr_line, c.children, flags)
        flags.in_row = false
      end
    end
  end


  return curr_line - first_line
end

function Ui:render(...)
  self.layout = {}
  self:_render(0, {...}, {})
end

function Ui.col(children, options)
  local options = options or {}
  return {
    tag = "col",
    children = children,
    options = options
  }
end

function Ui.row(children, options)
  local options = options or {}
  return {
    tag = "row",
    children = children,
    options = options
  }
end

function Ui.text(...)
  local options = {}
  local text = ""
  for _, arg in ipairs({...}) do
    if type(arg) == "table" then
      options = arg
    else
      text = text .. tostring(arg)
    end
  end

  return {
    tag = "text",
    value = text,
    options = options
  }
end

return Ui
