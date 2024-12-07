---@class Ui
local Ui = require("neogit.lib.ui")

function Ui:debug(...)
  Ui.visualize_tree { ... }
end

--- Will only work if something has been rendered
function Ui:debug_layout()
  Ui.visualize_tree(self.layout)
end

function Ui.visualize_tree(components)
  local tree = {}
  Ui._visualize_tree(1, components, tree)

  vim.lsp.util.open_floating_preview(tree, "txt", {
    relative = "editor",
    anchor = "NW",
    wrap = false,
    width = vim.o.columns - 2,
    height = vim.o.lines - 2,
  })
end

function Ui._visualize_tree(indent, components, tree)
  for _, c in ipairs(components) do
    table.insert(tree, Ui._draw_component(indent, c))

    if c.tag == "col" or c.tag == "row" then
      Ui._visualize_tree(indent + 1, c.children, tree)
    end
  end
end

-- function Ui.visualize_component(c, options)
--   Ui._print_component(0, c, options or {})
--
--   if c.tag == "col" or c.tag == "row" then
--     Ui._visualize_tree(1, c.children, options or {})
--   end
-- end

function Ui._draw_component(indent, c, _)
  local output = string.rep("  ", indent)
  if c.position then
    local text = ""
    if c.position.row_start == c.position.row_end then
      text = c.position.row_start
    else
      text = c.position.row_start .. " - " .. c.position.row_end
    end

    if c.position.col_end ~= -1 then
      text = text .. " | " .. c.position.col_start .. " - " .. c.position.col_end
    end

    output = output .. "[" .. text .. "]"
  end

  output = output .. " " .. c:get_tag()

  if c.tag == "text" then
    output = output .. " '" .. c.value .. "'"
  end

  for k, v in pairs(c.options) do
    if k ~= "tag" then
      output = output .. " " .. k .. "=" .. tostring(v)
    end
  end

  return output
end
