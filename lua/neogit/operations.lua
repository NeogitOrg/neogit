local a = require('plenary.async_lib')
-- This is a table to look up pending neogit operations.
-- An operation is loosely defined as a user-triggered, top-level execution
-- like "commit", "stash" or "pull".
-- This module exists mostly as a stop-gap, since plenary's busted port cannot
-- currently test asynchronous operations.
-- Since operations are usually triggered by keyboard shortcuts but run async,
-- dependent code has a hard time synchronizing with the execution.
-- To solve this issue, neogit operations will register themselves here in a
-- table. Dependent code can then look up the invoked operation and track it's
-- execution status.

local k_state = {}
local M = {
  [k_state] = {}
}
local meta = {}

function M.wait(key, time)
  vim.wait(time or 1000, function () return not M[k_state][key] end, 100)
end

function meta.__call(tbl, key, async)
  return function (...)
    local args = {...}
    tbl[k_state][key] = true
    a.scope(function ()
      await(async(unpack(args)))
      M[k_state][key] = false
    end)
  end
end

return setmetatable(M, meta)
