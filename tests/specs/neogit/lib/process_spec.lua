local Process = require("neogit.process")
local async = require("neogit.lib.async")

--- Drives the event loop until `predicate()` returns true (or `timeout` ms elapse).
local function wait_for(predicate, timeout)
  return vim.wait(timeout or 2000, predicate, 5)
end

describe("process", function()
  describe("on_exit resilience", function()
    -- Regression: on_exit runs presentation logic (error display, console
    -- show/close) *before* invoking the resume callback. If any of it threw, the
    -- callback was skipped and the awaiting coroutine was orphaned -- and because
    -- popup actions hold a shared permit lock across the await, that silently
    -- wedged every subsequent popup action until Neovim restarted.
    it("still resumes the awaiting coroutine when on_error throws", function()
      local outcome
      async.run(function()
        local proc = Process.new {
          cmd = { "sh", "-c", "exit 1" }, -- non-zero exit -> triggers on_error
          suppress_console = true,
          on_error = function()
            error("on-error-boom")
          end,
        }
        outcome = { result = proc:spawn_async() }
      end)

      local resolved = wait_for(function()
        return outcome ~= nil
      end, 3000)

      assert.is_truthy(resolved) -- did not hang
      assert.is_truthy(outcome.result) -- got a ProcessResult back despite the throw
      assert.are.equal(1, outcome.result.code)
    end)

    it("does not park the coroutine when the process fails to spawn", function()
      -- Regression: on spawn failure the callback was dead code after `error()`,
      -- so the awaiting coroutine was never resumed. The coroutine must always
      -- unwind (resolve to nil per contract, or at worst re-raise) -- never park.
      local outcome
      async.run(function()
        local proc = Process.new {
          cmd = { "neogit-nonexistent-command-xyzzy" },
          suppress_console = true,
          on_error = function()
            return true
          end,
        }
        local ok, result = pcall(function()
          return proc:spawn_async()
        end)
        outcome = { ok = ok, result = result }
      end)

      local resolved = wait_for(function()
        return outcome ~= nil
      end, 3000)

      assert.is_truthy(resolved) -- did not hang
      if outcome.ok then
        assert.is_nil(outcome.result) -- spawn failure resolves to nil per contract
      end
    end)
  end)
end)
