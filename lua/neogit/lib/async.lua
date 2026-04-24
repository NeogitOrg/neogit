--- Coroutine-based async library for Neogit.
---
--- Drop-in replacement for the subset of plenary.async used by Neogit:
---   wrap, run, void, util.scheduler, util.run_all, util.block_on, control.Semaphore
---
--- How it works:
---   An async context is a coroutine driven by an internal step-function.
---   Leaf functions (created by `wrap`) yield `(fn, argc, user_args...)` back
---   to step, which then invokes the underlying I/O routine, passing step
---   itself as the trailing callback.  When the I/O completes, step is called,
---   the coroutine is resumed with the callback's arguments, and execution
---   continues from the yield point.

local M = {}

--- Registry of coroutines created by this module.  Used by `wrap` to detect
--- whether yielding will land in our step-function or in some unrelated
--- coroutine (e.g. plenary's test runner).  Weak-keyed so dead threads
--- garbage-collect.
local our_threads = setmetatable({}, { __mode = "k" })

--- Detect whether we're currently executing inside an async context that this
--- module created.  Any other coroutine (plenary.busted, user code, etc.) is
--- treated as "not our context" so a missing-callback call produces a clear
--- error instead of yielding into an unrelated scheduler.
local function in_async_context()
  local co = coroutine.running()
  return co ~= nil and our_threads[co] == true
end

--- Internal: start an async function and call `callback(ok, ...)` with its
--- success status and return values (or error / traceback on failure).
---@param async_fn function
---@param callback function|nil  fun(ok: boolean, ...: any)
local function execute(async_fn, callback, ...)
  local thread = coroutine.create(async_fn)
  our_threads[thread] = true

  local step
  step = function(...)
    -- Guard against callbacks invoked more than once or after completion.
    if coroutine.status(thread) == "dead" then
      return
    end

    local results = { coroutine.resume(thread, ...) }
    local ok = results[1]

    if not ok then
      -- Capture traceback from the failing coroutine before it's gone.
      local err = results[2]
      local tb = debug.traceback(thread, tostring(err))
      if callback then
        callback(false, err, tb)
      else
        -- Fire-and-forget: defer so the throw lands on the event loop with
        -- the original traceback intact.
        vim.schedule(function()
          error("[neogit async] " .. tb, 0)
        end)
      end
      return
    end

    if coroutine.status(thread) == "dead" then
      if callback then
        -- results = { true, retvals... }
        local retvals = {}
        for i = 2, #results do
          retvals[i - 1] = results[i]
        end
        callback(true, unpack(retvals, 1, #results - 1))
      end
      return
    end

    -- The coroutine yielded (fn, argc, user_args...).  Reconstruct the call
    -- as fn(user_args..., step) and let it drive the next resumption.
    local fn = results[2]
    local argc = results[3]
    if type(fn) ~= "function" or type(argc) ~= "number" then
      error(
        "[neogit async] coroutine yielded an unexpected value; "
          .. "did you call coroutine.yield directly instead of using async.wrap?"
      )
    end

    local user_args = {}
    for i = 4, #results do
      user_args[i - 3] = results[i]
    end
    user_args[argc] = step
    fn(unpack(user_args, 1, argc))
  end

  step(...)
end

--- Convert a callback-style function into an awaitable async function.
---
--- When called *inside* an async context with fewer than `argc` arguments
--- (i.e., without the callback), the function suspends the current coroutine
--- and the step machinery supplies the callback when resuming.
---
--- When called *outside* an async context with all `argc` args explicitly,
--- it behaves like the original function (caller supplies the callback).
---
--- Calling outside an async context with fewer than `argc` args is an error:
--- there is no coroutine to suspend.
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

--- Run an async function from a non-async context.
---@param async_fn function
---@param callback function|nil  Called with the function's return values on completion.
function M.run(async_fn, callback)
  if not callback then
    execute(async_fn, nil)
    return
  end
  -- Adapt internal (ok, ...) callback to the public (...) contract.
  execute(async_fn, function(ok, ...)
    if ok then
      callback(...)
    end
  end)
end

--- Return a wrapper that runs `fn` in a fresh async context each time it is
--- called.  The wrapper discards any return values (fire-and-forget); errors
--- propagate to the event loop with a traceback.
---@param fn function
---@return function
function M.void(fn)
  return function(...)
    execute(fn, nil, ...)
  end
end

M.util = {}

--- Yield to the Neovim event-loop scheduler so that API calls can be made.
M.util.scheduler = M.wrap(vim.schedule, 1)

--- Run all async functions concurrently and call `callback` when every one has
--- finished.
---@param fns function[]
---@param callback function|nil
function M.util.run_all(fns, callback)
  local n = #fns
  if n == 0 then
    if callback then
      callback()
    end
    return
  end

  execute(function()
    local done = 0
    local resume_cb = nil
    local complete = false

    local function on_one_done()
      done = done + 1
      if done == n then
        complete = true
        if resume_cb then
          local cb = resume_cb
          resume_cb = nil
          cb()
        end
      end
    end

    for _, fn in ipairs(fns) do
      execute(fn, on_one_done)
    end

    if not complete then
      -- Park the outer coroutine until all sub-tasks report completion.
      coroutine.yield(function(cb)
        if complete then
          cb()
        else
          resume_cb = cb
        end
      end, 1)
    end
  end, callback and function(_ok)
    callback()
  end or nil)
end

--- Block Neovim until `async_fn` completes and return its results.
--- This is intentionally synchronous – use sparingly.
---@param async_fn function
---@param timeout number|nil  Milliseconds to wait before giving up (default 2000).
---@return any
function M.util.block_on(async_fn, timeout)
  local outcome = nil

  execute(async_fn, function(ok, ...)
    outcome = { ok = ok, values = { ... }, n = select("#", ...) }
  end)

  vim.wait(timeout or 2000, function()
    return outcome ~= nil
  end, 20, false)

  if not outcome then
    error("[neogit async] block_on timed out after " .. (timeout or 2000) .. " ms")
  end

  if not outcome.ok then
    -- Re-raise with traceback when available (values: err, traceback).
    error(outcome.values[2] or tostring(outcome.values[1]) or "block_on: async function failed", 0)
  end

  return unpack(outcome.values, 1, outcome.n)
end

M.control = {}

--- @class Semaphore
local Semaphore = {}
Semaphore.__index = Semaphore

--- Create a new Semaphore with the given number of permits.
---@param initial_permits number  Must be > 0.
---@return Semaphore
function Semaphore.new(initial_permits)
  assert(type(initial_permits) == "number" and initial_permits > 0, "Semaphore: initial_permits must be > 0")
  return setmetatable({ permits = initial_permits, _waiting = {} }, Semaphore)
end

--- Acquire a permit, blocking until one is available.
--- Returns a permit object whose `forget()` method releases the permit.
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
      -- Hand the permit off to the next waiter.
      table.remove(self._sem._waiting, 1)(self)
    end
  end

  permit._sem = self
  callback(permit)
end, 2)

M.control.Semaphore = Semaphore

return M
