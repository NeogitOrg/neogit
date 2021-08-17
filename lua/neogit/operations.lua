local a = require 'plenary.async'
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

local M = {}
local meta = {}

function M.wait(key, time)
  if M[key] == nil then return end
  vim.fn.wait(time or 1000, function () 
    return M[key] == false 
  end, 100)
end

function meta.__call(_tbl, key, async_func)
  return a.void(function (...)
    M[key] = true
    async_func(...)
    M[key] = false
  end)
end

return setmetatable(M, meta)
