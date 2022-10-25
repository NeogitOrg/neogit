local Buffer = require("neogit.lib.buffer")

local M = {}

function M.new(content, filename, on_close)
  local instance = {
    content = content,
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
    filetype = "NeogitRebaseTodo",
    buftype = "",
    kind = "split",
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
    initialize = function(buffer)
      buffer:set_lines(0, -1, false, self.content)

      -- NOTE: This avoids the user having to force to save the contents of the buffer.
      vim.cmd("silent w!")
    end,
  }
end

return M
