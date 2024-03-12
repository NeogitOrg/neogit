local M = {}

-- Some autocmd seems to be calling this still.. Maybe it's cached? No idea.
-- Without this, closing the neogit status buffer will create an error.
function M.close() end

return M
