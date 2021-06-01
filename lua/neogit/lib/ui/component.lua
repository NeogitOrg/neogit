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

function Component:get_padding_left()
  return (self.options.padding_left or 0) + (self.parent and self.parent:get_padding_left() or 0)
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

function Component.new(x)
  x.options = vim.tbl_extend("force", default_component_options, x.options or {})
  setmetatable(x, { __index = Component })
  return x
end

return Component
