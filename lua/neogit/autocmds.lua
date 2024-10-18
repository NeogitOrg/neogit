local M = {}

local api = vim.api

function M.setup()
  local a = require("plenary.async")
  local status_buffer = require("neogit.buffers.status")
  local git = require("neogit.lib.git")
  local group = require("neogit").autocmd_group

  api.nvim_create_autocmd({ "ColorScheme" }, {
    callback = function()
      local config = require("neogit.config")
      local highlight = require("neogit.lib.hl")

      highlight.setup(config.values)
    end,
    group = group,
  })

  local autocmd_disabled = false
  api.nvim_create_autocmd({ "BufWritePost", "ShellCmdPost", "VimResume" }, {
    callback = a.void(function(o)
      if
        not autocmd_disabled
        and status_buffer.is_open()
        and not api.nvim_get_option_value("filetype", { buf = o.buf }):match("^Neogit")
      then
        local path = git.files.relpath_from_repository(o.file)
        if path then
          status_buffer
            .instance()
            :dispatch_refresh({ update_diffs = { "*:" .. path } }, string.format("%s:%s", o.event, path))
        end
      end
    end),
    group = group,
  })

  --- vimpgrep creates and deletes lots of buffers so attaching to each one will
  --- waste lots of resource and even slow down vimgrep.
  api.nvim_create_autocmd({ "QuickFixCmdPre", "QuickFixCmdPost" }, {
    group = group,
    pattern = "*vimgrep*",
    callback = function(args)
      autocmd_disabled = args.event == "QuickFixCmdPre"
    end,
  })
end

return M
