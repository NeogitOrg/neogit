local Finder = require("neogit.lib.finder")
local async = require("neogit.lib.async")
local config = require("neogit.config")

--- Drives the event loop until `predicate()` returns true (or `timeout` ms elapse).
local function wait_for(predicate, timeout)
  return vim.wait(timeout or 1000, predicate, 5)
end

--- Open and enter a floating window, mimicking a `vim.ui.select` replacement
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

--- Run find_async inside an async task under the given `vim.ui.select` stub,
--- returning { value = ... } once it resolves (or nil if it hangs).
local function drive(ui_select_impl)
  local saved = vim.ui.select
  vim.ui.select = ui_select_impl

  local outcome = nil
  async.run(function()
    local f = Finder.create({}):add_entries { "one", "two", "three" }
    outcome = { value = f:find_async() }
  end)

  local resolved = wait_for(function()
    return outcome ~= nil
  end)

  vim.ui.select = saved
  return resolved and outcome or nil
end

describe("lib.finder", function()
  local saved_check_integration

  before_each(function()
    saved_check_integration = config.check_integration
    -- Force the vim.ui.select fallback branch: CI has telescope on the
    -- runtimepath, so without this stub the finder would take the telescope
    -- branch instead.
    config.check_integration = function()
      return false
    end
  end)

  after_each(function()
    config.check_integration = saved_check_integration
  end)

  describe("find_async", function()
    -- Regression: some vim.ui.select replacements only invoke their callback via
    -- their own confirm/cancel actions and skip it when the prompt window is
    -- closed another way. A dropped callback used to park the awaiting
    -- coroutine forever, wedging the shared popup action lock until restart.
    it("resumes as abort when the select prompt window closes without a callback", function()
      local outcome = drive(function(_, _opts, _on_choice)
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

    it("delivers the real selection even if the window closes right after", function()
      local outcome = drive(function(_, _opts, on_choice)
        local win = open_float()
        vim.defer_fn(function()
          on_choice("two") -- implementations call on_choice before closing
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end, 30)
      end)

      assert.is_truthy(outcome)
      assert.are.equal("two", outcome.value)
    end)

    it("returns nil on an explicit cancel", function()
      local outcome = drive(function(_, _opts, on_choice)
        on_choice(nil) -- no window at all
      end)

      assert.is_truthy(outcome)
      assert.is_nil(outcome.value)
    end)

    it("delivers a synchronous selection", function()
      local outcome = drive(function(_, _opts, on_choice)
        on_choice("three") -- no window at all
      end)

      assert.is_truthy(outcome)
      assert.are.equal("three", outcome.value)
    end)
  end)
end)
