local managers = {}

local function invoke(id, map_id)
  local manager = managers[id]
  local k = manager.map_id_to_key[map_id]
  local mapping = manager.mappings[k]

  if type(mapping) == "table" then
    mapping[2]()
  else
    mapping()
  end
end

local function build_call_string(id, k)
  return string.format([[<cmd>lua require 'neogit.lib.mappings_manager'.invoke(%d, %d)<CR>]], id, k)
end

local function new()
  local id = vim.api.nvim_win_get_buf(0)
  local mappings = {}
  local map_id_to_key = {}
  local manager = {
    id = id,
    mappings = mappings,
    map_id_to_key = map_id_to_key,
    register = function()
      for k,mapping in pairs(mappings) do
        local map_id = #map_id_to_key + 1
        local f_call = build_call_string(id, map_id)
        if type(mapping) == "table" then
          for _,m in pairs(vim.split(mapping[1], "")) do
            if type(mapping[2]) == "string" then
              f_call = mapping[2]
            elseif mapping[3] and m == "v" then
              f_call = f_call .. "<ESC>"
            end
            vim.api.nvim_buf_set_keymap(id, m, k, f_call, {
              silent = true,
              noremap = true,
              nowait = true
            })
          end
        else
          if type(mapping) == "string" then
            f_call = mapping
          end
          vim.api.nvim_buf_set_keymap(id, "n", k, f_call, {
            silent = true,
            noremap = true,
            nowait = true
          })
        end

        table.insert(map_id_to_key, k)
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
  build_call_string = build_call_string,
  delete = delete,
  invoke = invoke
}
