local config = require("neogit.config")
local M = {}

function M.setup()
  for key, val in pairs(config.values.signs) do
    if key == "hunk" or key == "item" or key == "section" then
      vim.fn.sign_define("NeogitClosed:" .. key, {
        text = val[1]
      })
      vim.fn.sign_define("NeogitOpen:" .. key, {
        text = val[2]
      })
    end
  end
end

return M
