local RebaseEditorBuffer = require("neogit.buffers.rebase_editor")
local CommitEditorBuffer = require("neogit.buffers.commit_editor")
local uv_utils = require("neogit.lib.uv")

local M = {}

function M.rebase_editor(target, on_unload)
  local content = uv_utils.read_file_sync(target)
  RebaseEditorBuffer.new(content, target, on_unload):open()
end

function M.commit_editor(target, on_unload)
  local content = uv_utils.read_file_sync(target)
  CommitEditorBuffer.new(content, target, on_unload):open()
end

return M
