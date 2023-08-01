local M = {}

local api = vim.api
local group = require("neogit").autocmd_group

function M.setup()
  api.nvim_create_autocmd({ "ColorScheme" }, {
    callback = require("neogit.lib.hl").setup,
    group = group,
  })
end

return M
