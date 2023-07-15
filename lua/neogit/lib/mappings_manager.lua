local managers = {}

---@alias Mapping string|function|MappingTable

---@class MappingTable
---@field [1] string mode
---@field [2] string|function command
---@field [3] boolean Escape visual mode

---@class MappingsManager
---@field mappings table<string, Mapping>
local MappingsManager = {}

function MappingsManager.invoke(id, map_id)
  local manager = managers[id]
  local k = manager.map_id_to_key[map_id]
  local mapping = manager.mappings[k]

  if type(mapping) == "table" then
    mapping[2]()
  else
    mapping()
  end
end

function MappingsManager.build_call_string(id, k)
  return string.format([[<cmd>lua require 'neogit.lib.mappings_manager'.invoke(%d, %d)<CR>]], id, k)
end

function MappingsManager.delete(id)
  managers[id] = nil
end

---@return MappingsManager
function MappingsManager.new(id)
  local mappings = {}
  local map_id_to_key = {}
  local manager = {
    id = id,
    mappings = mappings,
    map_id_to_key = map_id_to_key,
    register = function()
      for k, mapping in pairs(mappings) do
        local map_id = #map_id_to_key + 1
        local f_call = MappingsManager.build_call_string(id, map_id)
        if type(mapping) == "table" then
          for _, m in pairs(vim.split(mapping[1], "")) do
            if type(mapping[2]) == "string" then
              f_call = mapping[2]
            elseif mapping[3] and m == "v" then
              f_call = f_call .. "<ESC>"
            end
            vim.api.nvim_buf_set_keymap(id, m, k, f_call, {
              silent = true,
              noremap = true,
              nowait = true,
            })
          end
        else
          if type(mapping) == "string" then
            f_call = mapping
          end
          vim.api.nvim_buf_set_keymap(id, "n", k, f_call, {
            silent = true,
            noremap = true,
            nowait = true,
          })
        end

        table.insert(map_id_to_key, k)
      end
    end,
  }

  managers[id] = manager

  return manager
end

return MappingsManager
