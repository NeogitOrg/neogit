local async = require("neogit.lib.async")

--- Drives the event loop until `predicate()` returns true (or `timeout` ms elapse).
local function wait_for(predicate, timeout)
  vim.wait(timeout or 500, predicate, 5)
end

--- Async-friendly sleep used inside async contexts.
local sleep = async.wrap(function(ms, cb)
  vim.defer_fn(cb, ms)
end, 2)

describe("lib.async", function()
  describe("void + scheduler", function()
    it("yields to the scheduler and resumes after", function()
      local order = {}
      async.void(function()
        table.insert(order, "before")
        async.util.scheduler()
        table.insert(order, "after")
      end)()

      wait_for(function()
        return #order == 2
      end)

      assert.are.same({ "before", "after" }, order)
    end)
  end)

  describe("wrap", function()
    it("suspends until the wrapped callback fires", function()
      local order = {}
      async.void(function()
        table.insert(order, "start")
        sleep(20)
        table.insert(order, "after-sleep")
      end)()

      wait_for(function()
        return #order == 2
      end)

      assert.are.same({ "start", "after-sleep" }, order)
    end)

    it("calls the underlying function directly when all args are supplied", function()
      local captured
      local f = async.wrap(function(x, cb)
        cb(x * 2)
      end, 2)

      f(21, function(result)
        captured = result
      end)

      assert.are.equal(42, captured)
    end)

    it("errors with a clear message when called outside async context with too few args", function()
      local f = async.wrap(function(_x, _cb) end, 2)

      local ok, err = pcall(function()
        f("only-one-arg")
      end)

      assert.is_false(ok)
      assert.is_truthy(tostring(err):match("outside an async context"))
    end)
  end)

  describe("util.run_all", function()
    it("invokes the callback after every async fn completes", function()
      local log = {}

      async.void(function()
        async.util.run_all({
          function()
            sleep(15)
            table.insert(log, "a")
          end,
          function()
            sleep(5)
            table.insert(log, "b")
          end,
          function()
            sleep(25)
            table.insert(log, "c")
          end,
        }, function()
          table.insert(log, "all-done")
        end)
      end)()

      wait_for(function()
        return vim.tbl_contains(log, "all-done")
      end)

      assert.is_true(vim.tbl_contains(log, "a"))
      assert.is_true(vim.tbl_contains(log, "b"))
      assert.is_true(vim.tbl_contains(log, "c"))
      -- "all-done" must come after every individual completion.
      assert.are.equal("all-done", log[#log])
    end)

    it("invokes the callback synchronously when given an empty list", function()
      local called = false
      async.util.run_all({}, function()
        called = true
      end)
      assert.is_true(called)
    end)
  end)

  describe("util.block_on", function()
    it("returns the value from the async function", function()
      local result = async.util.block_on(function()
        sleep(5)
        return 42
      end, 1000)

      assert.are.equal(42, result)
    end)

    it("returns multiple values", function()
      local a, b, c = async.util.block_on(function()
        return 1, 2, 3
      end, 1000)

      assert.are.equal(1, a)
      assert.are.equal(2, b)
      assert.are.equal(3, c)
    end)

    it("re-raises errors thrown inside the async function", function()
      local ok, err = pcall(async.util.block_on, function()
        error("inner-boom")
      end, 1000)

      assert.is_false(ok)
      assert.is_truthy(tostring(err):match("inner%-boom"))
    end)
  end)

  describe("control.Semaphore", function()
    it("rejects non-positive permit counts", function()
      assert.has_error(function()
        async.control.Semaphore.new(0)
      end)
    end)

    it("enforces mutual exclusion across concurrent acquirers", function()
      local sem = async.control.Semaphore.new(1)
      local events = {}

      local function worker(id)
        return function()
          local permit = sem:acquire()
          table.insert(events, "acquired-" .. id)
          sleep(15)
          table.insert(events, "released-" .. id)
          permit:forget()
        end
      end

      local done = false
      async.void(function()
        async.util.run_all({ worker(1), worker(2), worker(3) }, function()
          done = true
        end)
      end)()

      wait_for(function()
        return done
      end, 1000)

      -- Verify at no point were two permits held simultaneously.
      local active = 0
      local max_active = 0
      for _, e in ipairs(events) do
        if e:match("^acquired") then
          active = active + 1
          if active > max_active then
            max_active = active
          end
        else
          active = active - 1
        end
      end

      assert.are.equal(1, max_active)
      assert.are.equal(6, #events)
    end)

    it("hands a permit to the next waiter when one becomes available", function()
      local sem = async.control.Semaphore.new(1)
      local events = {}
      local done = false

      async.void(function()
        async.util.run_all({
          function()
            local permit = sem:acquire()
            table.insert(events, "first-acquired")
            sleep(20)
            -- forget() synchronously hands the permit to the next waiter,
            -- so "second-acquired" is appended *during* this call.
            permit:forget()
            table.insert(events, "first-finished")
          end,
          function()
            -- Ensure first acquires before us.
            sleep(5)
            local permit = sem:acquire()
            table.insert(events, "second-acquired")
            permit:forget()
          end,
        }, function()
          done = true
        end)
      end)()

      wait_for(function()
        return done
      end, 1000)

      assert.are.same({
        "first-acquired",
        "second-acquired",
        "first-finished",
      }, events)
    end)
  end)

  describe("run", function()
    it("invokes its callback with the async function's return values", function()
      local got
      async.run(function()
        sleep(5)
        return "hello", "world"
      end, function(a, b)
        got = { a, b }
      end)

      wait_for(function()
        return got ~= nil
      end)

      assert.are.same({ "hello", "world" }, got)
    end)
  end)
end)
