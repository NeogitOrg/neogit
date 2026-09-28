local input = require("neogit.lib.input")
local async = require("neogit.lib.async")

--- Drives the event loop until `predicate()` returns true (or `timeout` ms elapse).
local function wait_for(predicate, timeout)
  return vim.wait(timeout or 1000, predicate, 5)
end

--- Open and enter a floating window, mimicking a `vim.ui.input` replacement
--- (e.g. snacks.nvim) that synchronously enters its prompt window.
local function open_float()
  local buf = vim.api.nvim_create_buf(false, true)
  return vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = 1,
    col = 1,
    width = 20,
    height = 1,
  })
end

--- Run get_user_input inside an async task under the given `vim.ui.input`
--- stub, returning { value = ... } once it resolves (or nil if it hangs).
local function drive(ui_input_impl)
  local saved = vim.ui.input
  vim.ui.input = ui_input_impl

  local outcome = nil
  async.run(function()
    outcome = { value = input.get_user_input("Prompt") }
  end)

  local resolved = wait_for(function()
    return outcome ~= nil
  end)

  vim.ui.input = saved
  return resolved and outcome or nil
end

describe("lib.input", function()
  describe("get_user_input", function()
    -- Regression: some vim.ui.input replacements only invoke on_confirm via
    -- their own confirm/cancel actions and skip it when the prompt window is
    -- closed another way. A dropped callback used to park the awaiting
    -- coroutine forever, wedging the shared popup action lock until restart.
    it("resumes as a cancel when the prompt window closes without a callback", function()
      local outcome = drive(function(_, _on_confirm)
        local win = open_float()
        vim.defer_fn(function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true) -- closed, no callback
          end
        end, 30)
      end)

      assert.is_truthy(outcome) -- did not hang
      assert.is_nil(outcome.value)
    end)

    it("delivers the real value even if the window closes right after", function()
      local outcome = drive(function(_, on_confirm)
        local win = open_float()
        vim.defer_fn(function()
          on_confirm("hello") -- implementations call on_confirm before closing
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end, 30)
      end)

      assert.is_truthy(outcome)
      assert.are.equal("hello", outcome.value)
    end)

    it("returns nil on an explicit cancel without double-resuming", function()
      local outcome = drive(function(_, on_confirm)
        local win = open_float()
        vim.defer_fn(function()
          on_confirm(nil)
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end, 30)
      end)

      assert.is_truthy(outcome)
      assert.is_nil(outcome.value)
    end)

    it("works with a synchronous cmdline-style implementation", function()
      local outcome = drive(function(_, on_confirm)
        on_confirm("typed") -- no window at all
      end)

      assert.is_truthy(outcome)
      assert.are.equal("typed", outcome.value)
    end)
  end)
end)
