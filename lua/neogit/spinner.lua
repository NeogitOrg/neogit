local util = require("neogit.lib.util")

-- If a cmd prompt is opened during render, we need to pause output to avoid annoying messages stacking in the UI.
local _paused = false
vim.api.nvim_create_autocmd("CmdlineEnter", {
  callback = function()
    _paused = true
  end,
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
  callback = function()
    _paused = false
  end,
})

---@class Spinner
---@field text string
---@field count number
---@field interval number
---@field pattern string[]
---@field timer uv_timer_t
local Spinner = {}
Spinner.__index = Spinner
Spinner.__current = nil

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
  if Spinner.__current then
    Spinner.__current:stop()
  end
  Spinner.__current = self

  if not self.timer then
    self.timer = assert(vim.uv.new_timer())
    self.timer:start(
      250,
      self.interval,
      vim.schedule_wrap(function()
        if _paused then
          return
        end

        self.count = self.count + 1
        local step = self.pattern[(self.count % #self.pattern) + 1]
        vim.api.nvim_echo({ { step .. " " .. self.text, "" } }, false, {
          id = "neogit-spinner",
          kind = "progress",
          status = "running",
          source = "neogit",
        })
      end)
    )
  end
end

function Spinner:stop()
  if self.timer then
    local timer = self.timer
    self.timer = nil
    timer:stop()

    vim.api.nvim_echo({ { "", "" } }, false, {
      id = "neogit-spinner",
      kind = "progress",
      status = "success",
      source = "neogit",
    })

    Spinner.__current = nil

    if not timer:is_closing() then
      timer:close()
    end
  end
end

---@param text string
function Spinner._test(text)
  if Spinner._spinner then
    Spinner._spinner:stop()
    Spinner._spinner = nil
  else
    Spinner._spinner = Spinner.new(text or "test spinner")
    Spinner._spinner:start()
  end
end

return Spinner
