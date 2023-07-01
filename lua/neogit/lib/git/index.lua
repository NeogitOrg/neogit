local M = {}

-- Make sure the index is in sync as git-status skips it
-- Do this manually since the `cli` add --no-optional-locks
function M.update()
  require("neogit.process")
    .new({ cmd = { "git", "update-index", "-q", "--refresh" }, verbose = true })
    :spawn_async()
end

function M.register(meta)
  meta.update_index = function(state)
    state.index.timestamp = state.index_stat()
  end
end

return M
