local util = require 'neogit.lib.util'

local default_component_options = {
  folded = false,
  hidden = false
}

local Component = {}

function Component:row_range_abs()
  if self.position.row_end == nil then
    return 0, 0
  end
  local from = self.position.row_start
  local len = self.position.row_end - from
  if self.parent.tag ~= "_root" then
    local p_from = self.parent:row_range_abs()
    from = from + p_from - 1
  end
  return from, from + len
end

function Component:toggle_hidden()
  self.options.hidden = not self.options.hidden
end

function Component:get_padding_left(recurse)
  local padding_left = self.options.padding_left or 0
  local padding_left_text = type(padding_left) == "string" and padding_left or (" "):rep(padding_left)
  if recurse == false then
    return padding_left_text
  end
  return padding_left_text .. (self.parent and self.parent:get_padding_left() or "")
end

function Component:is_hidden()
  return self.options.hidden or (self.parent and self.parent:is_hidden())
end

function Component:is_under_cursor(cursor)
  if self:is_hidden() then
    return false
  end
  local row = cursor[1]
  local col = cursor[2]
  local from, to = self:row_range_abs()
  local row_ok = from <= row and row <= to
  local col_ok = self.position.col_end == -1 
    or (self.position.col_start <= col and col <= self.position.col_end)
  return row_ok and col_ok
end

function Component:get_width()
  if self.tag == "text" then
    return #self.value
  end

  if self.tag == "row" then
    local width = 0
    for i=1,#self.children do
      width = width + self.children[i]:get_width()
    end
    return width
  end

  if self.tag == "col" then
    local width = 0
    for i=1,#self.children do
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

function Component:get_sign()
  return self.options.sign or (self.parent and self.parent:get_sign() or nil)
end

function Component:get_highlight()
  return self.options.highlight or (self.parent and self.parent:get_highlight() or nil)
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
    end
  })
  return x
end

return Component
