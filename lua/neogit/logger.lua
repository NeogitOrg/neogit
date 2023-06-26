local log = require("plenary.log")

return log.new {
  plugin = "neogit",
  highlights = vim.env.NEOGIT_LOG_HIGHLIGHTS or false,
  use_console = vim.env.NEOGIT_LOG_CONSOLE or false,
  use_file = vim.env.NEOGIT_LOG_FILE or false,
  level = vim.env.NEOGIT_LOG_LEVEL or "info",
}
