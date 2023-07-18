local M = {}

local api = vim.api
local a = require("plenary.async")
local status = require("neogit.status")
local fs = require("neogit.lib.fs")
local group = require("neogit").autocmd_group

function M.setup()
  api.nvim_create_autocmd({ "ColorScheme" }, {
    callback = require("neogit.lib.hl").setup,
    group = group,
  })

  api.nvim_create_autocmd({ "BufWritePost", "ShellCmdPost", "VimResume" }, {
    callback = function(o)
      -- Skip update if the buffer is not open
      if not status.status_buffer then
        return
      end

      -- Do not trigger on neogit buffers such as commit
      if api.nvim_buf_get_option(o.buf, "filetype"):find("Neogit") then
        return
      end

      a.run(function()
        local path = fs.relpath_from_repository(o.file)
        if not path then
          return
        end
        status.refresh({ status = true, diffs = { "*:" .. path } }, string.format("%s:%s", o.event, o.file))
      end, function() end)
    end,
    group = group,
  })
end

return M
