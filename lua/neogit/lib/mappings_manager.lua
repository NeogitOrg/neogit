managers = {}

function __NeogitMappingsManagerCall(id, k)
  local manager = managers[id]
  local f = manager.mappings[k]

  f()
end

local function key_to_vim(k)
  if k == "tab" then
    return "<TAB>"
  end
  return k
end

local function map_to_vim(m)
  local keys = vim.split(m, " ")
  local combo = ""
  for _, key in pairs(keys) do
    local parts = vim.split(key, "-")
    if parts[1] == "control" then
      combo = combo .. string.format("<C-%s>", key_to_vim(parts[2]))
    else
      combo = combo .. key_to_vim(parts[1])
    end
  end
  return combo
end

local function new()
  local id = vim.api.nvim_win_get_buf(0)
  local mappings = {}
  local manager = {
    id = id,
    mappings = mappings,
    register = function()
      for k,_ in pairs(mappings) do
        local f_call = string.format([[<cmd>lua __NeogitMappingsManagerCall(%d,'%s')<CR>]], id, k)
        vim.api.nvim_buf_set_keymap(id, "n", map_to_vim(k), f_call, {
          silent = true,
          noremap = true
        })
      end
    end
  }

  managers[id] = manager

  return manager
end

local function delete(id)
  managers[id] = nil
end

return {
  new = new,
  delete = delete
}
