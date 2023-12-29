local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")

local pad = util.pad_right

local M = {}

local filetypes = {
  ["COMMIT_EDITMSG"] = "NeogitCommitMessage",
  ["MERGE_MSG"] = "NeogitMergeMessage",
  ["TAG_EDITMSG"] = "NeogitTagMessage",
  ["EDIT_DESCRIPTION"] = "NeogitBranchDescription",
}

---@class EditorBuffer
---@field filename string filename of buffer
---@field on_unload function callback invoked when buffer is unloaded
---@field buffer Buffer
---@see Buffer

--- Creates a new EditorBuffer
---@param filename string the filename of buffer
---@param on_unload function the event dispatched on buffer unload
---@return EditorBuffer
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
  assert(kind, "Editor must specify a kind")

  local mapping = config.get_reversed_commit_editor_maps()
  local aborted = false
  local message_index = -1
  local current_message
  local footer

  self.buffer = Buffer.create {
    name = self.filename,
    filetype = filetypes[self.filename:match("[%u_]+$")] or "NeogitEditor",
    load = true,
    buftype = "",
    kind = kind,
    modifiable = true,
    readonly = false,
    after = function(buffer)
      -- Populate help lines with mappings for buffer
      local padding = util.max_length(util.flatten(vim.tbl_values(mapping)))
      local pad_mapping = function(name)
        return pad(mapping[name] and mapping[name][1] or "<NOP>", padding)
      end

      -- stylua: ignore
      local help_lines = {
        "#",
        "# Commands:",
        string.format("#   %s Close", pad_mapping("Close")),
        string.format("#   %s Submit", pad_mapping("Submit")),
        string.format("#   %s Abort", pad_mapping("Abort")),
        string.format("#   %s Previous Message", pad_mapping("PrevMessage")),
        string.format("#   %s Next Message", pad_mapping("NextMessage")),
      }

      help_lines = util.filter_map(help_lines, function(line)
        if not line:match("<NOP>") then -- mapping will be <NOP> if user unbinds key
          return line
        end
      end)

      local line = vim.fn.search("^#$") - 1
      buffer:set_lines(line, line, false, help_lines)
      buffer:write()
      buffer:move_cursor(1)

      footer = buffer:get_lines(1, -1, false)

      -- Start insert mode if user has configured it
      local disable_insert = config.values.disable_insert_on_commit
      if
        (disable_insert == "auto" and vim.fn.prevnonblank(".") ~= vim.fn.line("."))
        or not disable_insert
      then
        vim.cmd(":startinsert")
      end

      -- Source runtime ftplugin
      vim.cmd.source("$VIMRUNTIME/ftplugin/gitcommit.vim")

      -- Apply syntax highlighting
      local ok, _ = pcall(vim.treesitter.language.inspect, "gitcommit")
      if ok then
        vim.treesitter.start(buffer.handle, "gitcommit")
      else
        vim.cmd.source("$VIMRUNTIME/syntax/gitcommit.vim")
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
        [mapping["PrevMessage"]] = function(buffer)
          if message_index == -1 then
            current_message = buffer:get_lines(0, -1, false)
            current_message = util.slice(current_message, 1, #current_message - #footer)
          end

          message_index = message_index + 1

          local message = git.log.reflog_message(message_index)
          buffer:set_lines(0, -1, false, util.merge(message, footer))
          buffer:move_cursor(1)
        end,
        [mapping["NextMessage"]] = function(buffer)
          if message_index >= 0 then
            message_index = message_index - 1
          end

          local message
          if message_index < 0 then
            message = current_message
          else
            message = git.log.reflog_message(message_index)
          end

          buffer:set_lines(0, -1, false, util.merge(message, footer))
          buffer:move_cursor(1)
        end,
      },
    },
  }
end

return M
