local a = require("neogit.lib.async")

---@class NeogitGitLock
local M = {}

-- Serializes fetch/pull so a background fetch (e.g. `fetch_after_checkout`,
-- which runs fire-and-forget after a branch checkout) can't run concurrently
-- with a manually triggered fetch/pull. Concurrent fetches both write
-- `.git/FETCH_HEAD`, which can interleave and leave more than one ref marked
-- for merge, causing `fatal: Cannot fast-forward to multiple branches.`
M.fetch_pull = a.control.Semaphore.new(1)

return M
