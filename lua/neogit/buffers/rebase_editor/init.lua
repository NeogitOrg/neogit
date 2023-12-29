local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")

local pad = util.pad_right

local CommitViewBuffer = require("neogit.buffers.commit_view")

local M = {}

local function line_action(action)
  return function(buffer)
    local line = vim.split(vim.api.nvim_get_current_line(), " ")
    local comment_char = git.config.get_comment_char()
    if line[1] == comment_char then
      table.remove(line, 1)
    end

    -- Check if line is "break" or "exec"
    if line[1]:sub(1, 1):match("[be]") then
      vim.cmd("normal! j")
      return
    end

    if line[2] and line[2]:match("%x%x%x%x%x%x%x") and line[1] ~= "Rebase" then
      if #line[1] == 1 then
        action = action:sub(1, 1)
      end

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

function M:open(kind)
  local mapping = config.get_reversed_rebase_editor_maps()
  local aborted = false

  self.buffer = Buffer.create {
    name = self.filename,
    load = true,
    filetype = "NeogitRebaseTodo",
    buftype = "",
    kind = kind,
    modifiable = true,
    readonly = false,
    after = function(buffer)
      local padding = util.max_length(util.flatten(vim.tbl_values(mapping)))
      local pad_mapping = function(name)
        return pad(mapping[name] and mapping[name][1] or "<NOP>", padding)
      end

      local help_lines = ""
      if not config.values.disable_editor_help then
        local comment_char = git.config.get_comment_char()
        -- stylua: ignore
        help_lines = {
          string.format("%s", comment_char),
          string.format("%s Commands:", comment_char),
          string.format("%s   %s pick   = use commit", comment_char, pad_mapping("Pick")),
          string.format("%s   %s reword = use commit, but edit the commit message", comment_char, pad_mapping("Reword")),
          string.format("%s   %s edit   = use commit, but stop for amending", comment_char, pad_mapping("Edit")),
          string.format("%s   %s squash = use commit, but meld into previous commit", comment_char, pad_mapping("Squash")),
          string.format('%s   %s fixup  = like "squash", but discard this commit\'s log message', comment_char, pad_mapping("Fixup")),
          string.format("%s   %s exec   = run command (the rest of the line) using shell", comment_char, pad_mapping("Execute")),
          string.format("%s   %s drop   = remove commit", comment_char, pad_mapping("Drop")),
          string.format("%s   %s undo last change", comment_char, pad("u", padding)),
          string.format("%s   %s tell Git to make it happen",comment_char,  pad_mapping("Submit")),
          string.format("%s   %s tell Git that you changed your mind, i.e. abort", comment_char, pad_mapping("Abort")),
          string.format("%s   %s move the commit up", comment_char, pad_mapping("MoveUp")),
          string.format("%s   %s move the commit down", comment_char, pad_mapping("MoveDown")),
          string.format("%s   %s show the commit another buffer", comment_char, pad_mapping("OpenCommit")),
          string.format("%s", comment_char),
          string.format("%s These lines can be re-ordered; they are executed from top to bottom.", comment_char),
          string.format("%s", comment_char),
          string.format("%s If you remove a line here THAT COMMIT WILL BE LOST.", comment_char),
          string.format("%s", comment_char),
          string.format("%s However, if you remove everything, the rebase will be aborted.", comment_char),
          string.format("%s", comment_char),
        }

        help_lines = util.filter_map(help_lines, function(line)
          if not line:match("<NOP>") then -- mapping will be <NOP> if user unbinds key
            return line
          end
        end)

        buffer:set_lines(vim.fn.search(string.format("%s Commands:", comment_char)) - 1, -1, true, {})
        buffer:set_lines(-1, -1, false, help_lines)
      end

      buffer:write()
      buffer:move_cursor(1)

      -- Source runtime ftplugin
      vim.cmd.source("$VIMRUNTIME/ftplugin/gitrebase.vim")

      -- Apply syntax highlighting
      local ok, _ = pcall(vim.treesitter.language.inspect, "git_rebase")
      if ok then
        vim.treesitter.start(buffer.handle, "git_rebase")
      else
        vim.cmd.source("$VIMRUNTIME/syntax/gitrebase.vim")
      end
    end,
    autocmds = {
      ["BufUnload"] = function()
        pcall(vim.treesitter.stop, self.buffer.handle)

        if self.on_unload then
          self.on_unload(aborted and 1 or 0)
        end

        require("neogit.process").defer_show_preview_buffers()
      end,
    },
    mappings = {
      n = {
        [mapping["Close"]] = function(buffer)
          if buffer:get_option("modified") and not input.get_confirmation("Save changes?") then
            aborted = true
          end

          buffer:write()
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
          local comment_char = git.config.get_comment_char()
          if line:match(string.format("^%s ", comment_char)) then
            return
          end

          vim.api.nvim_set_current_line(string.format("%s " .. line, comment_char))
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
