local M = {}

local api = vim.api
local a = require("plenary.async")
local status_buffer = require("neogit.buffers.status")
local git = require("neogit.lib.git")
local group = require("neogit").autocmd_group

function M.setup()
  api.nvim_create_autocmd({ "ColorScheme" }, {
    callback = require("neogit.lib.hl").setup,
    group = group,
  })

  api.nvim_create_autocmd({ "BufWritePost", "ShellCmdPost", "VimResume" }, {
    callback = function(o)
      if not status_buffer.instance then
        return
      end

      -- Do not trigger on neogit buffers such as commit
      if api.nvim_get_option_value("filetype", { buf = o.buf }):find("Neogit") then
        return
      end

      a.run(function()
        local path = git.files.relpath_from_repository(o.file)
        if not path then
          return
        end

        if status_buffer.is_open() then
          status_buffer.instance:dispatch_refresh(
            { update_diffs = { "*:" .. path } },
            string.format("%s:%s", o.event, o.file)
          )
        end
      end, function() end)
    end,
    group = group,
  })
end

return M
