local util = require("neogit.lib.util")

local default_component_options = {
  foldable = false,
  folded = false,
}

---@class ComponentPosition
---@field row_start integer
---@field row_end integer
---@field col_start integer
---@field col_end integer

---@class ComponentOptions
---@field line_hl string
---@field highlight string
---@field align_right integer|nil
---@field padding_left integer
---@field tag string
---@field foldable boolean
---@field folded boolean
---@field context boolean
---@field interactive boolean
---@field virtual_text string

---@class Component
---@field position ComponentPosition
---@field parent Component
---@field children Component[]
---@field tag string|nil
---@field options ComponentOptions
---@field index number|nil
---@field value string|nil
---@field id string|nil
local Component = {}

function Component:row_range_abs()
  return self.position.row_start, self.position.row_end
end

function Component:get_padding_left(recurse)
  local padding_left = self.options.padding_left or 0
  local padding_left_text = type(padding_left) == "string" and padding_left or (" "):rep(padding_left)
  if recurse == false then
    return padding_left_text
  end
  return padding_left_text .. (self.parent and self.parent:get_padding_left() or "")
end

function Component:is_under_cursor(cursor)
  local row = cursor[1]
  local col = cursor[2]
  local from, to = self:row_range_abs()
  local row_ok = from <= row and row <= to
  local col_ok = self.position.col_end == -1
    or (self.position.col_start <= col and col <= self.position.col_end)

  return row_ok and col_ok
end

function Component:is_in_linewise_range(start, stop)
  local from, to = self:row_range_abs()
  return from >= start and from <= stop and to >= start and to <= stop
end

function Component:get_width()
  if self.tag == "text" then
    local width = string.len(self.value)
    -- local width = vim.fn.strdisplaywidth(self.value)
    if self.options.align_right then
      return width + (self.options.align_right - width)
    else
      return width
    end
  end

  if self.tag == "row" then
    local width = 0
    for i = 1, #self.children do
      width = width + self.children[i]:get_width()
    end
    return width
  end

  if self.tag == "col" then
    local width = 0
    for i = 1, #self.children do
      local c_width = self.children[i]:get_width()
      if c_width > width then
        width = c_width
      end
    end
    return width
  end

  error("UNIMPLEMENTED")
end

function Component:get_tag()
  if self.options.tag then
    return self.options.tag .. "<" .. self.tag .. ">"
  else
    return self.tag
  end
end

function Component:get_line_highlight()
  return self.options.line_hl or (self.parent and self.parent:get_line_highlight() or nil)
end

function Component:get_highlight()
  return self.options.highlight or (self.parent and self.parent:get_highlight() or nil)
end

function Component:append(c)
  table.insert(self.children, c)
  return self
end

function Component.new(f)
  local x = {}
  setmetatable(x, {
    __call = function(tbl, ...)
      local x = f(...)
      local options = vim.tbl_extend("force", default_component_options, tbl, x.options or {})
      x.options = options
      setmetatable(x, { __index = Component })
      return x
    end,
    __index = function(tbl, name)
      local value = rawget(Component, name)

      if value == nil then
        value = function(value)
          local options = util.deepcopy(tbl)
          options[name] = value
          return options
        end
      end

      return value
    end,
  })
  return x
end

return Component
