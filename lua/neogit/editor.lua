local RebaseEditorBuffer = require("neogit.buffers.rebase_editor")
local CommitEditorBuffer = require("neogit.buffers.commit_editor")
local MergeEditorBuffer = require("neogit.buffers.merge_editor")
local TagEditorBuffer = require("neogit.buffers.tag_editor")

local M = {}

function M.rebase_editor(target, on_unload)
  RebaseEditorBuffer.new(target, on_unload):open()
end

function M.commit_editor(target, on_unload)
  CommitEditorBuffer.new(target, on_unload):open()
end

function M.merge_editor(target, on_unload)
  MergeEditorBuffer.new(target, on_unload):open()
end

function M.tag_editor(target, on_unload)
  TagEditorBuffer.new(target, on_unload):open()
end

return M
