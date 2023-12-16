local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")

local pad = util.pad_right

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

function M.new(filename, on_unload)
  local instance = {
    filename = filename,
    on_unload = on_unload,
    buffer = nil,
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:open()
  local mapping = config.get_reversed_rebase_editor_maps()
  local aborted = false

  self.buffer = Buffer.create {
    name = self.filename,
    load = true,
    filetype = "NeogitRebaseTodo",
    buftype = "",
    kind = config.values.rebase_editor.kind,
    modifiable = true,
    readonly = false,
    after = function(buffer)
      local padding = util.max_length(util.flatten(vim.tbl_values(mapping)))
      local pad_mapping = function(name)
        return pad(mapping[name] and mapping[name][1] or "<NOP>", padding)
      end

      -- stylua: ignore
      local help_lines = {
        "# Neogit Commands:",
        string.format("#   %s pick   = use commit", pad_mapping("Pick")),
        string.format("#   %s reword = use commit, but edit the commit message", pad_mapping("Reword")),
        string.format("#   %s edit   = use commit, but stop for amending", pad_mapping("Edit")),
        string.format("#   %s squash = use commit, but meld into previous commit", pad_mapping("Squash")),
        string.format('#   %s fixup  = like "squash", but discard this commit\'s log message', pad_mapping("Fixup")),
        string.format("#   %s exec   = run command (the rest of the line) using shell", pad_mapping("Execute")),
        string.format("#   %s drop   = remove commit", pad_mapping("Drop")),
        string.format("#   %s undo last change", pad("u", padding)),
        string.format("#   %s tell Git to make it happen", pad_mapping("Submit")),
        string.format("#   %s tell Git that you changed your mind, i.e. abort", pad_mapping("Abort")),
        string.format("#   %s move the commit up", pad_mapping("MoveUp")),
        string.format("#   %s move the commit down", pad_mapping("MoveDown")),
        string.format("#   %s show the commit another buffer", pad_mapping("OpenCommit")),
        "#",
        "# These lines can be re-ordered; they are executed from top to bottom.",
        "#",
        "# If you remove a line here THAT COMMIT WILL BE LOST.",
        "#",
        "# However, if you remove everything, the rebase will be aborted.",
        "#",
      }

      help_lines = util.filter_map(help_lines, function(line)
        if not line:match("<NOP>") then -- mapping will be <NOP> if user unbinds key
          return line
        end
      end)

      buffer:set_lines(vim.fn.search("# Commands:") - 1, -1, true, {})
      buffer:set_lines(-1, -1, false, help_lines)
      buffer:write()
      buffer:move_cursor(1)
    end,
    autocmds = {
      ["BufUnload"] = function()
        if self.on_unload then
          self.on_unload(aborted and 1 or 0)
        end

        if not aborted then
          require("neogit.process").defer_show_preview_buffers()
        end
      end,
    },
    mappings = {
      n = {
        [mapping["Close"]] = function(buffer)
          if buffer:get_option("modified") and input.get_confirmation("Save changes?") then
            buffer:write()
          end

          buffer:close(true)
        end,
        [mapping["Submit"]] = function(buffer)
          buffer:write()
          buffer:close(true)
        end,
        [mapping["Abort"]] = function(buffer)
          aborted = true
          buffer:write()
          buffer:close(true)
        end,
        [mapping["Pick"]] = line_action("pick"),
        [mapping["Reword"]] = line_action("reword"),
        [mapping["Edit"]] = line_action("edit"),
        [mapping["Squash"]] = line_action("squash"),
        [mapping["Fixup"]] = line_action("fixup"),
        [mapping["Execute"]] = function(buffer)
          local exec = input.get_user_input("Execute: ")
          if not exec or exec == "" then
            return
          end

          buffer:insert_line("exec " .. exec)
        end,
        [mapping["Drop"]] = function()
          local line = vim.api.nvim_get_current_line()
          if line:match("^# ") then
            return
          end

          vim.api.nvim_set_current_line("# " .. line)
          vim.cmd("normal! j")
        end,
        [mapping["Break"]] = function(buffer)
          buffer:insert_line("break")
        end,
        [mapping["MoveUp"]] = function()
          vim.cmd("move -2")
        end,
        [mapping["MoveDown"]] = function()
          vim.cmd("move +1")
        end,
        [mapping["OpenCommit"]] = function()
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
