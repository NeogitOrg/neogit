local log = require("plenary.log")

return log.new {
  plugin = "neogit",
  highlights = false,
  use_console = vim.env.NEOGIT_LOG_ENABLE or false,
  use_file = vim.env.NEOGIT_LOG_ENABLE or false,
  level = vim.env.NEOGIT_LOG_LEVEL or "info",
}
