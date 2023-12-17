local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")

local pad = util.pad_right

local M = {}

---@class EditorBuffer
---@field filename string filename of buffer
---@field kind string Type of buffer to open, eg. tab, replace, split, vsplit
---@field filetype string neogit filetype for editor
---@field on_unload function callback invoked when buffer is unloaded
---@field buffer Buffer
---@see Buffer

--- Creates a new EditorBuffer
---@param filename string the filename of buffer
---@param on_unload function the event dispatched on buffer unload
---@return EditorBuffer
function M.new(filename, on_unload)
  local kind, filetype
  if filename:find("COMMIT_EDITMSG$") then
    kind = config.values.commit_editor.kind
    filetype = "NeogitCommitMessage"
  elseif filename:find("MERGE_MSG$") then
    kind = config.values.merge_editor.kind
    filetype = "NeogitMergeMessage"
  elseif filename:find("TAG_EDITMSG$") then
    kind = config.values.tag_editor.kind
    filetype = "NeogitTagMessage"
  elseif filename:find("EDIT_DESCRIPTION$") then
    kind = config.values.description_editor.kind
    filetype = "NeogitBranchDescription"
  end

  assert(kind, "Editor kind must be specified")
  assert(filetype, "Editor filetype must be specified")

  local instance = {
    kind = kind,
    filetype = filetype,
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
    filetype = self.filetype,
    load = true,
    buftype = "",
    kind = self.kind,
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

      local disable_insert = config.values.disable_insert_on_commit
      if
        (disable_insert == "auto" and vim.fn.prevnonblank(".") ~= vim.fn.line("."))
        or not disable_insert
      then
        vim.cmd(":startinsert")
      end
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
  }
end

return M
