local util = require("neogit.lib.util")
---@class Spinner
---@field text string
---@field count number
---@field interval number
---@field pattern string[]
---@field timer uv_timer_t
local Spinner = {}
Spinner.__index = Spinner

---@return Spinner
function Spinner.new(text)
  local instance = {
    text = util.str_truncate(text, vim.v.echospace - 2, "..."),
    interval = 100,
    count = 0,
    timer = nil,
    pattern = {
      "⠋",
      "⠙",
      "⠹",
      "⠸",
      "⠼",
      "⠴",
      "⠦",
      "⠧",
      "⠇",
      "⠏",
    },
  }

  return setmetatable(instance, Spinner)
end

function Spinner:start()
  if not self.timer then
    self.timer = vim.uv.new_timer()
    self.timer:start(
      250,
      self.interval,
      vim.schedule_wrap(function()
        self.count = self.count + 1
        local step = self.pattern[(self.count % #self.pattern) + 1]
        vim.cmd(string.format("echo '%s %s' | redraw", step, self.text))
      end)
    )
  end
end

function Spinner:stop()
  if self.timer then
    local timer = self.timer
    self.timer = nil
    timer:stop()

    if not timer:is_closing() then
      timer:close()
    end
  end

  vim.schedule(function()
    vim.cmd("redraw | echomsg ''")
  end)
end

return Spinner
