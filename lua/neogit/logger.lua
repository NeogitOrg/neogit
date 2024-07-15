-- Inspired by rxi/log.lua
-- Modified by tjdevries and can be found at github.com/tjdevries/vlog.nvim
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.

-- User configuration section
local default_config = {
  plugin = "neogit",

  use_console = vim.env.NEOGIT_LOG_CONSOLE or false,
  highlights = vim.env.NEOGIT_LOG_HIGHLIGHTS or (vim.env.NEOGIT_LOG_CONSOLE or false),
  use_file = vim.env.NEOGIT_LOG_FILE or false,
  level = vim.env.NEOGIT_LOG_LEVEL or "info",

  modes = {
    { name = "trace", hl = "Comment" },
    { name = "debug", hl = "Comment" },
    { name = "info", hl = "None" },
    { name = "warn", hl = "WarningMsg" },
    { name = "error", hl = "ErrorMsg" },
    { name = "fatal", hl = "ErrorMsg" },
  },

  float_precision = 0.01,
}

-- NO NEED TO CHANGE BELOW HERE
local log = {}

log.new = function(config, standalone)
  config = vim.tbl_deep_extend("force", default_config, config)

  local outfile =
    string.format("%s/%s.log", vim.api.nvim_call_function("stdpath", { "cache" }), config.plugin)

  local obj
  if standalone then
    obj = log
  else
    obj = {}
  end

  local levels = {}
  for i, v in ipairs(config.modes) do
    levels[v.name] = i
  end

  local round = function(x, increment)
    increment = increment or 1
    x = x / increment
    return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
  end

  local make_string = function(...)
    local t = {}
    for i = 1, select("#", ...) do
      local x = select(i, ...)

      if type(x) == "number" and config.float_precision then
        x = tostring(round(x, config.float_precision))
      elseif type(x) == "table" then
        x = vim.inspect(x)
      else
        x = tostring(x)
      end

      t[#t + 1] = x
    end
    return table.concat(t, " ")
  end

  local log_at_level = function(level, level_config, message_maker, ...)
    -- Return early if we're below the config.level
    if level < levels[config.level] then
      return
    end
    local nameupper = level_config.name:upper():sub(1, 1)

    if vim.tbl_isempty { ... } then
      return
    end

    local msg = message_maker(...)
    local info = debug.getinfo(2, "Sl")
    local lineinfo = info.short_src:gsub(".+/neogit/lua/neogit/", "") .. ":" .. info.currentline

    -- Output to console
    if config.use_console then
      local console_string = string.format("[%-6s%s] %s: %s", nameupper, os.date("%H:%M:%S"), lineinfo, msg)

      if config.highlights and level_config.hl then
        vim.cmd(string.format("echohl %s", level_config.hl))
      end

      local split_console = vim.split(console_string, "\n")
      for _, v in ipairs(split_console) do
        vim.cmd(string.format([[echom "[%s] %s"]], config.plugin, vim.fn.escape(v, '"')))
      end

      if config.highlights and level_config.hl then
        vim.cmd("echohl NONE")
      end
    end

    -- Output to log file
    if config.use_file then
      vim.uv.update_time()
      local time = tostring(vim.uv.now())

      local m = time:sub(4, 4)
      local s = time:sub(5, 6)
      local ms = time:sub(7)
      local fp = io.open(outfile, "a")
      local str = string.format("[%s %s.%s.%-3s] %-30s %s\n", nameupper, m, s, ms, lineinfo, msg)
      if fp then
        fp:write(str)
        fp:close()
      end
    end
  end

  for i, x in ipairs(config.modes) do
    obj[x.name] = function(...)
      return log_at_level(i, x, make_string, ...)
    end

    obj[("fmt_%s"):format(x.name)] = function(...)
      local passed = { ... }
      return log_at_level(i, x, function()
        local fmt = table.remove(passed, 1)
        local inspected = {}
        for _, v in ipairs(passed) do
          table.insert(inspected, vim.inspect(v))
        end

        return string.format(fmt, unpack(inspected))
      end)
    end
  end
end

log.new(default_config, true)

return log
