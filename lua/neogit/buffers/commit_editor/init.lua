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
function M.new(content, filename, on_unload)
  local instance = {
    content = content,
    filename = filename,
    on_unload = on_unload,
    buffer = nil,
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:open()
  local written = false
  self.buffer = Buffer.create {
    name = self.filename,
    filetype = "NeogitCommitMessage",
    buftype = "",
    kind = config.values.commit_popup.kind,
    modifiable = true,
    readonly = false,
    autocmds = {
      ["BufWritePost"] = function()
        written = true
      end,
      ["BufUnload"] = function()
        if written then
          if
            config.values.disable_commit_confirmation
            or input.get_confirmation("Are you sure you want to commit?")
          then
            vim.cmd("silent g/^#/d | silent w!")
          end
        end

        if self.on_unload then
          self.on_unload(written)
        end
        require("neogit.process").defer_show_preview_buffers()
      end,
    },
    mappings = {
      n = {
        ["q"] = function(buffer)
          buffer:close(true)
        end,
      },
    },
    initialize = function(buffer)
      buffer:set_lines(0, -1, false, self.content)
      if not config.values.disable_insert_on_commit then
        vim.cmd(":startinsert")
      end

      -- NOTE: This avoids the user having to force to save the contents of the buffer.
      vim.cmd("silent w!")
    end,
  }
end

return M
