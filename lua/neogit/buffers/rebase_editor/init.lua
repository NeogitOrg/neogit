local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")

local M = {}

function M.new(filename, on_close)
  local instance = {
    filename = filename,
    on_close = on_close,
    buffer = nil,
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:open()
  self.buffer = Buffer.create {
    name = self.filename,
    load = true,
    filetype = "NeogitRebaseTodo",
    buftype = "",
    kind = config.values.rebase_editor.kind,
    modifiable = true,
    readonly = false,
    autocmds = {
      ["BufUnload"] = function()
        self.on_close()
        vim.cmd("silent w!")
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
  }
end

return M
