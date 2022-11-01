local log = require("plenary.log")

return log.new {
  plugin = "neogit",
  highlights = false,
  use_console = false,
  use_file = false,
  level = "debug",
}
