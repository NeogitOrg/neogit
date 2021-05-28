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

function Ui._print_component(indent, c, options)
  local output = string.rep("  ", indent)
  if c.options.hidden then
    output = output .. "(H)"
  elseif c.position then
    local text = ""
    if c.position.row_start == c.position.row_end then
      text = c.position.row_start
    else
      text = c.position.row_start .. " - " .. c.position.row_end
    end

    if c.position.col_start then
      text = text .. " | " .. c.position.col_start .. " - " .. c.position.col_end
    end

    output = output .. "[" .. text .. "]"
  end

  if c.options.tag then
    output = output .. " " .. c.options.tag .. "<" .. c.tag .. ">"
  else
    output = output .. " " .. c.tag
  end

  if c.tag == "text" then
    output = output .. " '" .. c.value .. "'"
  end

  if c.options.sign then
    output = output .. " sign=" .. c.options.sign
  end

  print(output)
end

function Ui._visualize_tree(indent, components, options)
  for _, c in ipairs(components) do
    Ui._print_component(indent, c, options)
    if (c.tag == "col" or c.tag == "row")
      and not (options.collapse_hidden_components and c.options.hidden)
      then
      Ui._visualize_tree(indent + 1, c.children, options)
    end
  end
end

function Ui._find_component(components, f, options)
  for _, c in ipairs(components) do
    if (options.include_hidden and c.options.hidden) or not c.options.hidden then
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
  end

  return nil
end


--- if biggest is true the biggest element gets returned
function Ui:find_component(f, options)
  return Ui._find_component(self.layout, f, options or {})
end

function Ui:get_component_under_cursor()
  local curr_line = vim.api.nvim_win_get_cursor(0)[1]
  return self:find_component(function(c)
    local from, to = c:row_range_abs()
    return from <= curr_line and curr_line <= to
  end)
end

function Ui.visualize_component(c, options)
  Ui._print_component(0, c, options or {})
  if c.tag == "col" or c.tag == "row" then
    Ui._visualize_tree(1, c.children, options or {})
  end
end

function Ui.visualize_tree(components, options)
  print("root")
  Ui._visualize_tree(1, components, options or {})
end

function Ui:_render(first_line, parent, components, flags)
  local curr_line = first_line
  
  if flags.in_row then
    local col_start = 0
    local col_end
    local highlights = {}
    local sign = nil
    local text = ""

    for i, c in ipairs(components) do
      c.position = {}
      if not c.options.hidden then
        c.parent = parent
        c.position.row_start = curr_line - first_line + 1
        sign = c.options.sign or c.parent.options.sign
        local highlight = c.options.highlight or c.parent.options.highlight
        if c.tag == "text" then
          col_end = col_start + #c.value
          c.position.col_start = col_start
          c.position.col_end = col_end - 1
          text = text .. c.value
          if highlight then
            table.insert(highlights, {
              from = col_start,
              to = col_end,
              name = highlight
            })
          end
          col_start = col_end
        else
          error("The row component does not support having a `" .. c.tag .. "` as child")
        end
        c.position.row_end = c.position.row_start
      end
    end

    self.buf:set_lines(curr_line - 1, curr_line, false, { text })

    for _, h in ipairs(highlights) do
      self.buf:add_highlight(curr_line - 1, h.from, h.to, h.name, 0)
    end

    if sign then
      self.buf:place_sign(curr_line - 1, sign, "hl")
    end

    curr_line = curr_line + 1
  else
    for i, c in ipairs(components) do
      if not c.options.hidden then
        c.position = {}
        c.parent = parent
        c.position.row_start = curr_line - first_line + 1
        local sign = c.options.sign or c.parent.options.sign
        local highlight = c.options.highlight or c.parent.options.highlight
        if c.tag == "text" then
          self.buf:set_lines(curr_line - 1, curr_line, false, { c.value })
          curr_line = curr_line + 1
          if highlight then
            self.buf:add_highlight(curr_line - 1, 0, -1, highlight, 0)
          end
          if sign then
            self.buf:place_sign(curr_line - 1, sign, "hl")
          end
        elseif c.tag == "col" then
          curr_line = curr_line + self:_render(curr_line, c, c.children, flags)
        elseif c.tag == "row" then
          flags.in_row = true
          curr_line = curr_line + self:_render(curr_line, c, c.children, flags)
          flags.in_row = false
        end
        c.position.row_end = curr_line - first_line
      end
    end
  end

  return curr_line - first_line
end

function Ui:render(...)
  self.layout = {...}
  self:update()
end

function Ui:update()
  self.buf:unlock()
  local lines_used = self:_render(1, {
    tag = "_root",
    children = self.layout,
    options = {}
  }, self.layout, {})
  self.buf:set_lines(lines_used, -1, false, {})
  self.buf:lock()
end

--- Will only work if something has been rendered
function Ui:print_layout_tree(options)
  Ui.visualize_tree(self.layout, options)
end

function Ui:debug(...)
  Ui.visualize_tree({...}, {})
end

local default_component_options = {
  folded = false,
  hidden = false
}

local Component = {}

function Component:row_range_abs()
  local from = self.position.row_start
  local to = self.position.row_start
  if self.parent.tag ~= "_root" then
    local p_from, p_to = self.parent:row_range_abs()
    from = from + p_from - 1
    to = to + p_to - 1
  end
  return from, to
end

function Component:toggle_hidden()
  self.options.hidden = not self.options.hidden
end

local function new_comp(x)
  x.options = vim.tbl_extend("force", default_component_options, x.options or {})
  setmetatable(x, { __index = Component })
  return x
end

function Ui.col(children, options)
  return new_comp({
    tag = "col",
    children = children,
    options = options
  })
end

function Ui.row(children, options)
  return new_comp({
    tag = "row",
    children = children, id = "test",
    options = options
  })
end

function Ui.text(...)
  local text = ""
  local options
  for _, arg in ipairs({...}) do
    if type(arg) == "table" then
      options = arg
    else
      text = text .. tostring(arg)
    end
  end

  return new_comp({
    tag = "text",
    value = text,
    options = options
  })
end

return Ui
