-- function! neogit#complete(arglead, ...)
--   return luaeval('require("neogit").complete')(a:arglead)
-- endfunction

-- command! -nargs=* -complete=customlist,neogit#complete
--       \ Neogit lua require'neogit'.open(require'neogit.lib.util'.parse_command_args(<f-args>))<CR>
local M = {}
local api = vim.api

function M.setup()
  api.nvim_create_user_command("Neogit", function(o)
    local neogit = require("neogit")
    neogit.open(require("neogit.lib.util").parse_command_args(o.fargs))
  end, {
    nargs = "*",
    desc = "Open Neogit",
    complete = function(arglead)
      local neogit = require("neogit")
      return neogit.complete(arglead)
    end,
  })
end

return M
