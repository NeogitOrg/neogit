local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")

local pad = util.pad_right

local M = {}

-- @class CommitEditorBuffer
-- @field content content of buffer
-- @field filename filename of buffer
-- @field on_unload callback distached on unload
-- @field buffer Buffer
-- @see Buffer
-- @see Ui

--- Creates a new CommitEditorBuffer
-- @param content the content of buffer
-- @param filename the filename of buffer
-- @param on_unload the event dispatched on buffer unload
-- @return CommitEditorBuffer
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
  local mapping = config.get_reversed_commit_editor_maps()
  local aborted = false

  self.buffer = Buffer.create {
    name = self.filename,
    filetype = "NeogitCommitMessage",
    load = true,
    buftype = "",
    kind = config.values.commit_editor.kind,
    modifiable = true,
    readonly = false,
    after = function(buffer)
      local padding = util.max_length(util.flatten(vim.tbl_values(mapping)))
      local pad_mapping = function(name)
        return pad(mapping[name][1], padding)
      end

      -- stylua: ignore
      local help_lines = {
        "# Neogit Commands:",
        string.format("#   %s close", pad_mapping("Close")),
        string.format("#   %s tell Git to make it happen", pad_mapping("Submit")),
        string.format("#   %s tell Git that you changed your mind, i.e. abort", pad_mapping("Abort")),
        "#"
      }

      help_lines = util.filter_map(help_lines, function(line)
        if not line:match("<NOP>") then -- mapping will be <NOP> if user unbinds key
          return line
        end
      end)

      local line = vim.fn.search("# Changes to be committed:") - 2
      buffer:set_lines(line, line, false, help_lines)
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
      },
    },
    initialize = function(buffer)
      vim.api.nvim_buf_call(buffer.handle, function()
        local disable_insert = config.values.disable_insert_on_commit
        if
          (disable_insert == "auto" and vim.fn.prevnonblank(".") ~= vim.fn.line("."))
          or not disable_insert
        then
          vim.cmd(":startinsert")
        end
      end)
    end,
  }
end

return M
