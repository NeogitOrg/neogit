local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")

local M = {}

function M.new(filename, on_unload)
  local instance = {
    filename = filename,
    on_unload = on_unload,
    buffer = nil,
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:open()
  self.buffer = Buffer.create {
    name = self.filename,
    load = true,
    filetype = "NeogitTagMessage",
    buftype = "",
    kind = config.values.tag_editor.kind,
    modifiable = true,
    readonly = false,
    autocmds = {
      ["BufUnload"] = function()
        self.on_unload()
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
