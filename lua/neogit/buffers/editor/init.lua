local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")
local logger = require("neogit.logger")
local process = require("neogit.process")

local DiffViewBuffer = require("neogit.buffers.diff")

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
---@field show_diff boolean show the diff view or not
---@field buffer Buffer
---@see Buffer

--- Creates a new EditorBuffer
---@param filename string the filename of buffer
---@param on_unload function the event dispatched on buffer unload
---@return EditorBuffer
function M.new(filename, on_unload, show_diff)
  local instance = {
    show_diff = show_diff,
    filename = filename,
    on_unload = on_unload,
    buffer = nil,
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:open(kind)
  assert(kind, "Editor must specify a kind")
  logger.debug("[EDITOR] Opening editor as " .. kind)

  local mapping = config.get_reversed_commit_editor_maps()
  local mapping_I = config.get_reversed_commit_editor_maps_I()
  local aborted = false

  local message_index = 1
  local message_buffer = { { "" } }
  local amend_header, footer, diff_view

  local function reflog_message(index)
    return git.log.reflog_message(index - 2)
  end

  local function commit_message()
    return message_buffer[message_index] or reflog_message(message_index)
  end

  local function current_message(buffer)
    local message = buffer:get_lines(0, -1)
    message = util.slice(message, 1, math.max(1, #message - #footer))

    return message
  end

  local filetype = filetypes[self.filename:match("[%u_]+$")] or "NeogitEditor"
  logger.debug("[EDITOR] Filetype " .. filetype)

  self.buffer = Buffer.create {
    name = self.filename,
    filetype = filetype,
    load = true,
    buftype = "",
    kind = kind,
    modifiable = true,
    status_column = "",
    readonly = false,
    autocmds = {
      ["QuitPre"] = function() -- For :wq compatibility
        if diff_view then
          diff_view:close()
          diff_view = nil
        end
      end,
    },
    on_detach = function(buffer)
      logger.debug("[EDITOR] Cleaning Up")
      pcall(vim.treesitter.stop, buffer.handle)

      if self.on_unload then
        logger.debug("[EDITOR] Running on_unload callback")
        self.on_unload(aborted and 1 or 0)
      end

      process.defer_show_preview_buffers()

      if diff_view then
        logger.debug("[EDITOR] Closing diff view")
        diff_view:close()
        diff_view = nil
      end

      logger.debug("[EDITOR] Done cleaning up")
    end,
    after = function(buffer)
      -- Populate help lines with mappings for buffer
      local padding = util.max_length(util.flatten(vim.tbl_values(mapping)))
      local pad_mapping = function(name)
        return pad(mapping[name] and mapping[name][1] or "<NOP>", padding)
      end

      local comment_char = git.config.get("core.commentChar"):read()
        or git.config.get_global("core.commentChar"):read()
        or "#"

      logger.debug("[EDITOR] Using comment character '" .. comment_char .. "'")

      -- stylua: ignore
      local help_lines = {
        ("%s"):format(comment_char),
        ("%s Commands:"):format(comment_char),
        ("%s   %s Close"):format(comment_char, pad_mapping("Close")),
        ("%s   %s Submit"):format(comment_char, pad_mapping("Submit")),
        ("%s   %s Abort"):format(comment_char, pad_mapping("Abort")),
        ("%s   %s Previous Message"):format(comment_char, pad_mapping("PrevMessage")),
        ("%s   %s Next Message"):format(comment_char, pad_mapping("NextMessage")),
        ("%s   %s Reset Message"):format(comment_char, pad_mapping("ResetMessage")),
      }

      help_lines = util.filter_map(help_lines, function(line)
        if not line:match("<NOP>") then -- mapping will be <NOP> if user unbinds key
          return line
        end
      end)

      local line = vim.fn.search(string.format("^%s$", comment_char)) - 1
      buffer:set_lines(line, line, false, help_lines)
      buffer:write()
      buffer:move_cursor(1)

      amend_header = buffer:get_lines(0, 2)
      if amend_header[1]:match("^amend! %x+$") then
        logger.debug("[EDITOR] Found 'amend!' header")

        buffer:set_lines(0, 2, false, {}) -- remove captured header from buffer
      else
        amend_header = nil
      end

      footer = buffer:get_lines(1, -1)

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
        logger.debug("[EDITOR] Loading treesitter for gitcommit")
        vim.treesitter.start(buffer.handle, "gitcommit")
      else
        logger.debug("[EDITOR] Loading syntax for gitcommit")
        vim.cmd.source("$VIMRUNTIME/syntax/gitcommit.vim")
      end

      if git.branch.current() then
        vim.fn.matchadd("NeogitBranch", git.branch.current(), 100)
      end

      if git.branch.upstream() then
        vim.fn.matchadd("NeogitRemote", git.branch.upstream(), 100)
      end

      if self.show_diff then
        logger.debug("[EDITOR] Opening Diffview for staged changes")
        diff_view = DiffViewBuffer:new("Staged Changes"):open()
      end
    end,
    mappings = {
      i = {
        [mapping_I["Submit"]] = function(buffer)
          logger.debug("[EDITOR] Action I: Submit")
          vim.cmd.stopinsert()
          if amend_header then
            buffer:set_lines(0, 0, false, amend_header)
          end

          buffer:write()
          buffer:close(true)
        end,
        [mapping_I["Abort"]] = function(buffer)
          logger.debug("[EDITOR] Action I: Abort")
          vim.cmd.stopinsert()
          aborted = true
          buffer:write()
          buffer:close(true)
        end,
      },
      n = {
        [mapping["Close"]] = function(buffer)
          logger.debug("[EDITOR] Action N: Close")
          if amend_header then
            buffer:set_lines(0, 0, false, amend_header)
          end

          if buffer:get_option("modified") and not input.get_confirmation("Save changes?") then
            aborted = true
          end

          buffer:write()
          buffer:close(true)
        end,
        [mapping["Submit"]] = function(buffer)
          logger.debug("[EDITOR] Action N: Submit")
          if amend_header then
            buffer:set_lines(0, 0, false, amend_header)
          end

          buffer:write()
          buffer:close(true)
        end,
        [mapping["Abort"]] = function(buffer)
          logger.debug("[EDITOR] Action N: Abort")
          aborted = true
          buffer:write()
          buffer:close(true)
        end,
        [mapping["PrevMessage"]] = function(buffer)
          logger.debug("[EDITOR] Action N: PrevMessage")
          local message = current_message(buffer)
          message_buffer[message_index] = message

          message_index = message_index + 1

          buffer:set_lines(0, #message, false, commit_message())
          buffer:move_cursor(1)
        end,
        [mapping["NextMessage"]] = function(buffer)
          logger.debug("[EDITOR] Action N: NextMessage")
          local message = current_message(buffer)

          if message_index > 1 then
            message_buffer[message_index] = message
            message_index = message_index - 1
          end

          buffer:set_lines(0, #message, false, commit_message())
          buffer:move_cursor(1)
        end,
        [mapping["ResetMessage"]] = function(buffer)
          logger.debug("[EDITOR] Action N: ResetMessage")
          local message = current_message(buffer)
          buffer:set_lines(0, #message, false, reflog_message(message_index))
          buffer:move_cursor(1)
        end,
      },
    },
  }
end

return M
