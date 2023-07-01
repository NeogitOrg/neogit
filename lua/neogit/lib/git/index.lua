local M = {}

-- Make sure the index is in sync as git-status skips it
-- Do this manually since the `cli` add --no-optional-locks
function M.update()
  require("neogit.process")
    .new({ cmd = { "git", "update-index", "-q", "--refresh" }, verbose = true })
    :spawn_async()
end

return M
