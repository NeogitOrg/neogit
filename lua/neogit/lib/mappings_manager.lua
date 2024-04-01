local managers = {}

---@alias Mapping string|function|MappingTable

---@class MappingTable
---@field [1] string mode
---@field [2] string|function func

---@class MappingsManager
---@field mappings table<string, Mapping>
---@field callbacks table
---@field id number
---@field register fun():nil
local MappingsManager = {}
MappingsManager.__index = MappingsManager

function MappingsManager.invoke(id, map_id)
  managers[id].callbacks[map_id]()
end

---@param id number The id of the manager
---@param index number The index of the map
---@param mode string vim mode from vim.fn.mode()
---@return string
function MappingsManager.build_call_string(id, index, mode)
  return string.format(
    "<cmd>lua require('neogit.lib.mappings_manager').invoke(%d, %d)<CR>%s",
    id,
    index,
    mode == "v" and "<esc>" or ""
  )
end

---@param id number The id of the manager
---@return nil
function MappingsManager.delete(id)
  managers[id] = nil
end

---@return MappingsManager
function MappingsManager.new(id)
  local mappings = { n = {}, v = {}, i = {} }
  local callbacks = {}
  local map_id = 1
  local manager = {
    id = id,
    callbacks = callbacks,
    mappings = mappings,
    register = function()
      for mode, mode_mappings in pairs(mappings) do
        for k, mapping in pairs(mode_mappings) do
          vim.keymap.set(
            mode,
            k,
            MappingsManager.build_call_string(id, map_id, mode),
            { buffer = id, nowait = true, silent = true, noremap = true }
          )

          callbacks[map_id] = mapping
          map_id = map_id + 1
        end
      end
    end,
  }

  managers[id] = manager

  return manager
end

return MappingsManager
