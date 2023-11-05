local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local input = require("neogit.lib.input")

local M = {}

-- @class CommitEditorBuffer
-- @field content content of buffer
-- @field filename filename of buffer
-- @field on_unload callback distached on unload
-- @field buffer Buffer
-- @see Buffer
-- @see Ui

--- Creates a new CommitEditorBuffer
-- @param content the content of buffer
-- @param filename the filename of buffer
-- @param on_unload the event dispatched on buffer unload
-- @return CommitEditorBuffer
function M.new(filename, on_unload)
  local instance = {
    filename = filename,
    on_unload = on_unload,
    buffer = nil,
  }

  setmetatable(instance, { __index = M })

  return instance
end

local confirmed = config.values.disable_commit_confirmation

-- Define mappable actions
local map_actions = {
  send = function(buffer)
    if not confirmed then
      confirmed = input.get_confirmation("Are you sure you want to commit?")
      if confirmed and vim.bo.mod then
        vim.cmd("silent w!")
      end
    end
    if not confirmed and config.values.disable_commit_close_on_deny then
      return
    end
    buffer:close(true)
  end,
  close = function(buffer)
    buffer:close(true)
  end,
}

-- Assign actions to keys (single keys or tables of keys)
local mappings = { n = {} }
for action, command in pairs(map_actions) do
  local action_mapping = config.values.mappings.commit[action]

  if type(action_mapping) == "string" then
    mappings.n[action_mapping] = command
  elseif type(action_mapping) == "table" then
    for _, map in pairs(action_mapping) do
      mappings.n[map] = command
    end
  end
end

function M:open()
  confirmed = config.values.disable_commit_confirmation

  self.buffer = Buffer.create {
    name = self.filename,
    filetype = "NeogitCommitMessage",
    load = true,
    buftype = "",
    kind = config.values.commit_editor.kind,
    modifiable = true,
    readonly = false,
    autocmds = {
      ["BufUnload"] = function(o)
        if not confirmed then
          vim.api.nvim_buf_set_lines(o.buf, 0, -1, false, {})
          vim.api.nvim_buf_call(o.buf, function()
            vim.cmd("silent w!")
          end)
        end

        if self.on_unload then
          self.on_unload()
        end

        require("neogit.process").defer_show_preview_buffers()
      end,
    },
    mappings = mappings,
    initialize = function(buffer)
      vim.api.nvim_buf_call(buffer.handle, function()
        local disable_insert = config.values.disable_insert_on_commit
        if
          (disable_insert == "auto" and vim.fn.prevnonblank(".") ~= vim.fn.line("."))
          or not disable_insert
        then
          vim.cmd(":startinsert")
        end
      end)
    end,
  }
end

return M
