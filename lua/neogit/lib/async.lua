--- Coroutine-based async library for Neogit.
---
--- Drop-in replacement for the subset of plenary.async used by Neogit:
---   wrap, run, void, util.scheduler, util.run_all, util.block_on,
---   control.Semaphore
---
--- How it works:
---   An async context is a coroutine driven by an internal step-function.
---   Leaf functions (created by `wrap`) yield `(fn, argc, user_args...)` back
---   to step, which then invokes the underlying I/O routine, passing step
---   itself as the trailing callback.  When the I/O completes, step is called,
---   the coroutine is resumed with the callback's arguments, and execution
---   continues from the yield point.
---
--- Cancellation:
---   `run` / `void` / `util.run_all` return a `Task`.  Calling `task:cancel()`
---   marks the task cancelled; if it is currently suspended on a wrapped fn
---   that returned a "cancel handle" function, the handle is invoked (this is
---   how `Process:spawn_async` kills its underlying job).  Future resumptions
---   of the coroutine become no-ops.  For `run_all`, cancellation propagates
---   to all in-flight sub-tasks.

local M = {}

--- Registry of coroutines created by this module.  Used by `wrap` to detect
--- whether yielding will land in our step-function or in some unrelated
--- coroutine (e.g. plenary's test runner).  Weak-keyed so dead threads
--- garbage-collect.
local our_threads = setmetatable({}, { __mode = "k" })

local function in_async_context()
  local co = coroutine.running()
  return co ~= nil and our_threads[co] == true
end

---@class NeogitTask
---@field _done boolean
---@field _cancelled boolean
---@field _ok boolean|nil
---@field _values table|nil   { ... } returned by the async fn (or err info on failure)
---@field _nvalues number     count of _values (for nil-safe unpack)
---@field _current_child function|nil  cancel-handle for the currently suspended wrapped fn
---@field _on_complete function[]
---@field _cancel_extra function[] extra cancel hooks (e.g. cancelling sub-tasks)
local Task = {}
Task.__index = Task

local function task_new()
  return setmetatable({
    _done = false,
    _cancelled = false,
    _ok = nil,
    _values = nil,
    _nvalues = 0,
    _current_child = nil,
    _on_complete = {},
    _cancel_extra = {},
  }, Task)
end

--- True if the task has finished (successfully, with error, or cancelled).
function Task:done()
  return self._done
end

--- True if cancel() has been called on this task.
function Task:cancelled()
  return self._cancelled
end

--- Cancel the task.  Idempotent.  Invokes the cancel-handle of the currently
--- suspended operation (if any) and any registered extra cancel hooks (e.g.
--- those that cancel sub-tasks of `run_all`).
function Task:cancel()
  if self._done or self._cancelled then
    return
  end
  self._cancelled = true

  local child = self._current_child
  self._current_child = nil
  if child then
    pcall(child)
  end

  for _, hook in ipairs(self._cancel_extra) do
    pcall(hook)
  end
  self._cancel_extra = {}

  -- Drive completion if the wrapped op didn't fire its callback (e.g. a
  -- process killed via its cancel handle whose on_exit hasn't landed yet).
  -- Delivers (cancelled=true, ok=false, "cancelled") to on_complete.
  if not self._done and self._finish then
    self._finish(false, { "cancelled" }, 1)
  end
end

--- Register a callback to fire when the task completes.  If the task is
--- already complete, the callback is invoked immediately.  Receives
--- (cancelled, ok, ...).
function Task:on_complete(cb)
  if self._done then
    cb(self._cancelled, self._ok, unpack(self._values or {}, 1, self._nvalues))
  else
    table.insert(self._on_complete, cb)
  end
end

--- Block Neovim until the task completes (or `timeout` ms pass).
--- Returns (done, cancelled).
function Task:wait(timeout)
  vim.wait(timeout or 2000, function()
    return self._done
  end, 20, false)
  return self._done, self._cancelled
end

--- Internal: start `async_fn` on the given task.  When complete, fires the
--- task's on_complete callbacks and the optional `callback(ok, ...)`.
local function execute(task, async_fn, callback, ...)
  local thread = coroutine.create(async_fn)
  our_threads[thread] = true

  local function finish(ok, values, n)
    if task._done then
      return
    end
    task._done = true
    task._ok = ok
    task._values = values
    task._nvalues = n or 0
    task._current_child = nil
    task._finish = nil

    if callback then
      callback(ok, unpack(values or {}, 1, task._nvalues))
    end

    local cbs = task._on_complete
    task._on_complete = {}
    for _, cb in ipairs(cbs) do
      cb(task._cancelled, ok, unpack(values or {}, 1, task._nvalues))
    end
  end

  -- Expose finish so Task:cancel() can complete a task whose wrapped fn
  -- never invokes its callback (the typical case for an external resource
  -- like a process: cancellation kills it without firing the callback).
  task._finish = finish

  local step
  step = function(...)
    -- Previous wrapped fn has completed; clear its cancel handle.
    task._current_child = nil

    if coroutine.status(thread) == "dead" then
      return
    end

    if task._cancelled then
      -- Don't resume; finish with cancelled status.  Mark thread effectively
      -- dead by removing from our registry.
      our_threads[thread] = nil
      finish(false, { "cancelled" }, 1)
      return
    end

    local results = { coroutine.resume(thread, ...) }
    local ok = results[1]

    if not ok then
      local err = results[2]
      local tb = debug.traceback(thread, tostring(err))
      finish(false, { err, tb }, 2)
      return
    end

    if coroutine.status(thread) == "dead" then
      local retvals = {}
      for i = 2, #results do
        retvals[i - 1] = results[i]
      end
      finish(true, retvals, #results - 1)
      return
    end

    local fn = results[2]
    local argc = results[3]
    if type(fn) ~= "function" or type(argc) ~= "number" then
      local err = "[neogit async] coroutine yielded an unexpected value; "
        .. "did you call coroutine.yield directly instead of using async.wrap?"
      finish(false, { err, err }, 2)
      return
    end

    local user_args = {}
    for i = 4, #results do
      user_args[i - 3] = results[i]
    end
    user_args[argc] = step

    -- The wrapped fn may return a function that cancels the operation it
    -- just kicked off (e.g. killing a process).  Stash it on the task so
    -- cancel() can invoke it.
    local cancel_handle = fn(unpack(user_args, 1, argc))
    if type(cancel_handle) == "function" and not task._done then
      task._current_child = cancel_handle
    end
  end

  step(...)
end

--- Convert a callback-style function into an awaitable async function.
---
--- When called *inside* an async context with fewer than `argc` arguments
--- (i.e., without the callback), the function suspends the current coroutine
--- and the step machinery supplies the callback when resuming.  The wrapped
--- function may optionally return a cancel-handle (a function) which the
--- machinery stashes on the current task; `task:cancel()` invokes it.
---
--- When called *outside* an async context with all `argc` args explicitly,
--- it behaves like the original function (caller supplies the callback).
---
--- Calling outside an async context with fewer than `argc` args is an error.
---
---@param fn function  Callback-style function; callback is the last argument.
---@param argc number  Total argument count including the callback position.
---@return function
function M.wrap(fn, argc)
  assert(type(fn) == "function", "async.wrap: expected function, got " .. type(fn))
  assert(type(argc) == "number", "async.wrap: argc must be a number")

  return function(...)
    local nargs = select("#", ...)
    if nargs >= argc then
      return fn(...)
    end
    if not in_async_context() then
      error(
        "[neogit async] wrapped function called outside an async context "
          .. "without supplying a callback (expected "
          .. argc
          .. " args, got "
          .. nargs
          .. "). Wrap the call in async.run/async.void or pass a callback explicitly.",
        2
      )
    end
    return coroutine.yield(fn, argc, ...)
  end
end

--- Run `async_fn` from a non-async context.  Returns a Task for cancellation
--- and completion observation.  `callback` (optional) is invoked with the
--- function's return values on successful completion.  When no callback is
--- supplied, an error inside `async_fn` is re-thrown on the event loop with
--- the captured traceback (so fire-and-forget errors aren't swallowed).
---@param async_fn function
---@param callback function|nil
---@return NeogitTask
function M.run(async_fn, callback)
  local task = task_new()
  if callback then
    execute(task, async_fn, function(ok, ...)
      if ok then
        callback(...)
      end
    end)
  else
    execute(task, async_fn, nil)
    task:on_complete(function(cancelled, ok, err, tb)
      if not ok and not cancelled then
        vim.schedule(function()
          error("[neogit async] " .. (tb or tostring(err) or "unknown error"), 0)
        end)
      end
    end)
  end
  return task
end

--- Return a wrapper that runs `fn` in a fresh async context each time it is
--- called.  The wrapper returns a Task; errors propagate to the event loop
--- with a traceback (unless someone explicitly observes the task).
---@param fn function
---@return function fun(...): NeogitTask
function M.void(fn)
  return function(...)
    local task = task_new()
    execute(task, fn, nil, ...)
    task:on_complete(function(cancelled, ok, err, tb)
      if not ok and not cancelled then
        vim.schedule(function()
          error("[neogit async] " .. (tb or tostring(err) or "unknown error"), 0)
        end)
      end
    end)
    return task
  end
end

M.util = {}

--- Yield to the Neovim event-loop scheduler so that API calls can be made.
M.util.scheduler = M.wrap(vim.schedule, 1)

--- Run all async functions concurrently and call `callback` when every one has
--- finished.  Returns a Task; cancelling it cancels every in-flight child.
---@param fns function[]
---@param callback function|nil
---@return NeogitTask
function M.util.run_all(fns, callback)
  local task = task_new()
  local n = #fns

  if n == 0 then
    task._done = true
    task._ok = true
    task._values = {}
    if callback then
      callback()
    end
    return task
  end

  local sub_tasks = {}
  local done = 0

  -- Cancelling the parent cancels every child.
  table.insert(task._cancel_extra, function()
    for _, t in ipairs(sub_tasks) do
      t:cancel()
    end
  end)

  local function on_one()
    done = done + 1
    if done == n and not task._done then
      task._done = true
      task._ok = not task._cancelled
      task._values = {}
      if callback and not task._cancelled then
        callback()
      end
      local cbs = task._on_complete
      task._on_complete = {}
      for _, cb in ipairs(cbs) do
        cb(task._cancelled, task._ok)
      end
    end
  end

  for _, fn in ipairs(fns) do
    local sub = M.run(fn)
    sub:on_complete(function()
      on_one()
    end)
    table.insert(sub_tasks, sub)
  end

  return task
end

--- Block Neovim until `async_fn` completes and return its results.
--- Use sparingly.
---@param async_fn function
---@param timeout number|nil  Milliseconds to wait before giving up (default 2000).
---@return any
function M.util.block_on(async_fn, timeout)
  local outcome = nil

  local task = task_new()
  execute(task, async_fn, function(ok, ...)
    outcome = { ok = ok, values = { ... }, n = select("#", ...) }
  end)

  vim.wait(timeout or 2000, function()
    return outcome ~= nil
  end, 20, false)

  if not outcome then
    task:cancel()
    error("[neogit async] block_on timed out after " .. (timeout or 2000) .. " ms")
  end

  if not outcome.ok then
    error(outcome.values[2] or tostring(outcome.values[1]) or "block_on: async function failed", 0)
  end

  return unpack(outcome.values, 1, outcome.n)
end

M.Task = Task

M.control = {}

---@class Semaphore
local Semaphore = {}
Semaphore.__index = Semaphore

function Semaphore.new(initial_permits)
  assert(type(initial_permits) == "number" and initial_permits > 0, "Semaphore: initial_permits must be > 0")
  return setmetatable({ permits = initial_permits, _waiting = {} }, Semaphore)
end

Semaphore.acquire = M.wrap(function(self, callback)
  if self.permits > 0 then
    self.permits = self.permits - 1
  else
    table.insert(self._waiting, callback)
    return
  end

  local permit = {}

  function permit:forget()
    self._sem.permits = self._sem.permits + 1
    if self._sem.permits > 0 and #self._sem._waiting > 0 then
      self._sem.permits = self._sem.permits - 1
      table.remove(self._sem._waiting, 1)(self)
    end
  end

  permit._sem = self
  callback(permit)
end, 2)

M.control.Semaphore = Semaphore

return M
