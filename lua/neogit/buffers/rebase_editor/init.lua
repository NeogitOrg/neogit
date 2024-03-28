local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")

local pad = util.pad_right

local CommitViewBuffer = require("neogit.buffers.commit_view")

local M = {}

local function line_action(action, comment_char)
  return function(buffer)
    local _index = 0
    local _count = vim.v.count
    local line = {}
    while _index <= _count do
      line = vim.split(vim.api.nvim_get_current_line(), " ")
      if line[1] == comment_char then
        table.remove(line, 1)
      end
      -- Check if line is "break" or "exec"
      -- the original match will also skip "edit",i'm not sure is that intended
      if line[1]:sub(1, 2):match("^(br|ex)") then
        vim.cmd("normal! j")
        if _index ~= 0 then
          break --or continue?i think break is used in most case
        end
        return
      end

      if line[2] and line[2]:match("%x%x%x%x%x%x%x") and line[1] ~= "Rebase" then
        if #line[1] == 1 then
          action = action:sub(1, 1)
        end

        line[1] = action
        vim.api.nvim_set_current_line(table.concat(line, " "))
      else
        break
      end

      vim.cmd("normal! j")
      _index = _index + 1
    end
    buffer:write()
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
  local comment_char = git.config.get("core.commentChar"):read()
    or git.config.get_global("core.commentChar"):read()
    or "#"

  local mapping = config.get_reversed_rebase_editor_maps()
  local aborted = false

  self.buffer = Buffer.create {
    name = self.filename,
    load = true,
    filetype = "NeogitRebaseTodo",
    buftype = "",
    kind = kind,
    modifiable = true,
    disable_line_numbers = config.values.disable_line_numbers,
    readonly = false,
    initialize = function(buffer)
      vim.api.nvim_buf_attach(buffer.handle, false, {
        on_detach = function()
          pcall(vim.treesitter.stop, buffer.handle)

          if self.on_unload then
            self.on_unload(aborted and 1 or 0)
          end

          require("neogit.process").defer_show_preview_buffers()
        end,
      })
    end,
    after = function(buffer)
      local padding = util.max_length(util.flatten(vim.tbl_values(mapping)))
      local pad_mapping = function(name)
        return pad(mapping[name] and mapping[name][1] or "<NOP>", padding)
      end

      -- stylua: ignore
      local help_lines = {
        ("%s Commands:"):format(comment_char),
        ("%s   %s pick   = use commit"):format(comment_char, pad_mapping("Pick")),
        ("%s   %s reword = use commit, but edit the commit message"):format(comment_char, pad_mapping("Reword")),
        ("%s   %s edit   = use commit, but stop for amending"):format(comment_char, pad_mapping("Edit")),
        ("%s   %s squash = use commit, but meld into previous commit"):format(comment_char, pad_mapping("Squash")),
        ('%s   %s fixup  = like "squash", but discard this commit\'s log message'):format(comment_char, pad_mapping("Fixup")),
        ("%s   %s exec   = run command (the rest of the line) using shell"):format(comment_char, pad_mapping("Execute")),
        ("%s   %s drop   = remove commit"):format(comment_char, pad_mapping("Drop")),
        ("%s   %s undo last change"):format(comment_char, pad("u", padding)),
        ("%s   %s tell Git to make it happen"):format(comment_char, pad_mapping("Submit")),
        ("%s   %s tell Git that you changed your mind, i.e. abort"):format(comment_char, pad_mapping("Abort")),
        ("%s   %s move the commit up"):format(comment_char, pad_mapping("MoveUp")),
        ("%s   %s move the commit down"):format(comment_char, pad_mapping("MoveDown")),
        ("%s   %s show the commit another buffer"):format(comment_char, pad_mapping("OpenCommit")),
        ("%s"):format(comment_char),
        ("%s These lines can be re-ordered; they are executed from top to bottom."):format(comment_char),
        ("%s"):format(comment_char),
        ("%s If you remove a line here THAT COMMIT WILL BE LOST."):format(comment_char),
        ("%s"):format(comment_char),
        ("%s However, if you remove everything, the rebase will be aborted."):format(comment_char),
        ("%s"):format(comment_char),
      }

      help_lines = util.filter_map(help_lines, function(line)
        if not line:match("<NOP>") then -- mapping will be <NOP> if user unbinds key
          return line
        end
      end)

      buffer:set_lines(vim.fn.search(string.format("%s Commands:", comment_char)) - 1, -1, true, {})
      buffer:set_lines(-1, -1, false, help_lines)
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
    mappings = {
      i = {
        [mapping["Submit"]] = function(buffer)
          vim.cmd.stopinsert()
          buffer:write()
          buffer:close(true)
        end,
        [mapping["Abort"]] = function(buffer)
          vim.cmd.stopinsert()
          aborted = true
          buffer:write()
          buffer:close(true)
        end,
      },
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
        [mapping["Pick"]] = line_action("pick", comment_char),
        [mapping["Reword"]] = line_action("reword", comment_char),
        [mapping["Edit"]] = line_action("edit", comment_char),
        [mapping["Squash"]] = line_action("squash", comment_char),
        [mapping["Fixup"]] = line_action("fixup", comment_char),
        [mapping["Execute"]] = function(buffer)
          local exec = input.get_user_input("Execute")
          if not exec then
            return
          end

          buffer:insert_line("exec " .. exec)
        end,
        [mapping["Drop"]] = function()
          local line = vim.api.nvim_get_current_line()
          if line:match(string.format("^%s ", comment_char)) then
            return
          end

          vim.api.nvim_set_current_line(string.format("%s %s", comment_char, line))
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
