local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local input = require("neogit.lib.input")

local CommitViewBuffer = require("neogit.buffers.commit_view")

local M = {}

local function line_action(action)
  return function()
    local line = vim.split(vim.api.nvim_get_current_line(), " ")
    if line[1] == "#" then
      table.remove(line, 1)
    end

    if line[1] == "break" or line[1] == "exec" then
      vim.cmd("normal! j")
      return
    end

    line[1] = action
    vim.api.nvim_set_current_line(table.concat(line, " "))
    vim.cmd("normal! j")
  end
end

function M.new(filename, on_close)
  local instance = {
    filename = filename,
    on_close = on_close,
    buffer = nil,
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:open()
  self.buffer = Buffer.create {
    name = self.filename,
    load = true,
    filetype = "NeogitRebaseTodo",
    buftype = "",
    kind = config.values.rebase_editor.kind,
    modifiable = true,
    readonly = false,
    autocmds = {
      ["BufUnload"] = function()
        self.on_close()
        vim.cmd("silent w!")
        require("neogit.process").defer_show_preview_buffers()
      end,
    },
    mappings = {
      n = {
        ["q"] = function(buffer)
          buffer:close(true)
        end,
        ["p"] = line_action("pick"),
        ["r"] = line_action("reword"),
        ["e"] = line_action("edit"),
        ["s"] = line_action("squash"),
        ["f"] = line_action("fixup"),
        ["x"] = function(buffer)
          local exec = input.get_user_input("Execute: ")
          if not exec or exec == "" then
            return
          end

          buffer:insert_line("exec " .. exec)
        end,
        ["d"] = function()
          local line = vim.api.nvim_get_current_line()
          if line:match("^# ") then
            return
          end

          vim.api.nvim_set_current_line("# " .. line)
          vim.cmd("normal! j")
        end,
        ["b"] = function(buffer)
          buffer:insert_line("break")
        end,
        ["<cr>"] = function()
          local oid = vim.api.nvim_get_current_line():match("(%x%x%x%x%x%x%x)")
          if oid then
            CommitViewBuffer.new(oid):open("tab")
          end
        end,
      },
    },
  }
end

return M
