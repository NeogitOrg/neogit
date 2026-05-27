local stub = require("luassert.stub")
local git = require("neogit.lib.git")
local runner = require("neogit.runner")
local config = require("neogit.config")
local branch = require("neogit.lib.git.branch")

describe("branch checkout await", function()
  local captured
  local hook_exists

  before_each(function()
    config.values = config.get_default_values()
    captured = nil
    hook_exists = false

    -- Capture the options passed to the runner instead of executing git.
    stub(runner, "call", function(_, opts)
      captured = opts
      return { stdout = {}, stderr = {}, output = {}, code = 0 }
    end)

    -- Control whether a post-checkout hook is reported as present.
    stub(git.hooks, "exists", function()
      return hook_exists
    end)
  end)

  after_each(function()
    runner.call:revert()
    git.hooks.exists:revert()
  end)

  it("runs async (await=false) when stream_hook_output is on and a post-checkout hook exists", function()
    config.values.stream_hook_output = true
    hook_exists = true
    branch.checkout("foo")
    assert.is_false(captured.await)
  end)

  it("blocks (await=true) when stream_hook_output is on but no post-checkout hook exists", function()
    config.values.stream_hook_output = true
    hook_exists = false
    branch.checkout("foo")
    assert.is_true(captured.await)
  end)

  it("blocks (await=true) when stream_hook_output is off even if a hook exists", function()
    config.values.stream_hook_output = false
    hook_exists = true
    branch.checkout("foo")
    assert.is_true(captured.await)
  end)

  it("applies the same logic to track()", function()
    config.values.stream_hook_output = true
    hook_exists = true
    branch.track("origin/foo")
    assert.is_false(captured.await)
  end)
end)
