local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local input = require("neogit.lib.input")

local CommitViewBuffer = require("neogit.buffers.commit_view")

local M = {}

local function line_action(action)
  return function(buffer)
    local line = vim.split(vim.api.nvim_get_current_line(), " ")
    if line[1] == "#" then
      table.remove(line, 1)
    end

    if line[1] == "break" or line[1] == "exec" then
      vim.cmd("normal! j")
      return
    end

    if line[2] and line[2]:match("%x%x%x%x%x%x%x%x%x%x") and line[1] ~= "Rebase" then
      line[1] = action
      vim.api.nvim_set_current_line(table.concat(line, " "))
      buffer:write()
    end

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
  local mappings = config.get_reversed_rebase_editor_maps()
  local aborted = false

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
        if self.on_close then
          self.on_close(aborted and 1 or 0)
        end

        if not aborted then
          require("neogit.process").defer_show_preview_buffers()
        end
      end,
    },
    mappings = {
      n = {
        [mappings["Close"]] = function(buffer)
          if buffer:get_option("modified") and input.get_confirmation("Save changes?") then
            buffer:write()
          end

          buffer:close(true)
        end,
        [mappings["Submit"]] = function(buffer)
          buffer:write()
          buffer:close(true)
        end,
        [mappings["Abort"]] = function(buffer)
          aborted = true
          buffer:close(true)
        end,
        [mappings["Pick"]] = line_action("pick"),
        [mappings["Reword"]] = line_action("reword"),
        [mappings["Edit"]] = line_action("edit"),
        [mappings["Squash"]] = line_action("squash"),
        [mappings["Fixup"]] = line_action("fixup"),
        [mappings["Execute"]] = function(buffer)
          local exec = input.get_user_input("Execute: ")
          if not exec or exec == "" then
            return
          end

          buffer:insert_line("exec " .. exec)
        end,
        [mappings["Drop"]] = function()
          local line = vim.api.nvim_get_current_line()
          if line:match("^# ") then
            return
          end

          vim.api.nvim_set_current_line("# " .. line)
          vim.cmd("normal! j")
        end,
        [mappings["Break"]] = function(buffer)
          buffer:insert_line("break")
        end,
        [mappings["MoveUp"]] = function()
          vim.cmd("move -2")
        end,
        [mappings["MoveDown"]] = function()
          vim.cmd("move +1")
        end,
        [mappings["OpenCommit"]] = function()
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
