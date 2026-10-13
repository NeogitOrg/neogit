local diff_actions = require("neogit.popups.diff.actions")
local git = require("neogit.lib.git")
local fuzzy_finder = require("neogit.buffers.fuzzy_finder")

describe("diff popup actions", function()
  local original_current, original_branches, original_tags, original_heads, original_fuzzy

  before_each(function()
    original_current = git.branch.current
    original_branches = git.branch.get_all_branches
    original_tags = git.tag.list
    original_heads = git.refs.heads
    original_fuzzy = fuzzy_finder.new
  end)

  after_each(function()
    git.branch.current = original_current
    git.branch.get_all_branches = original_branches
    git.tag.list = original_tags
    git.refs.heads = original_heads
    fuzzy_finder.new = original_fuzzy
  end)

  it("includes the current branch in range choices from the status view", function()
    local options
    local fuzzy_calls = 0

    git.branch.current = function()
      return "feature"
    end
    git.branch.get_all_branches = function()
      return { "main" }
    end
    git.tag.list = function()
      return {}
    end
    git.refs.heads = function()
      return {}
    end

    fuzzy_finder.new = function(choices)
      options = options or choices
      fuzzy_calls = fuzzy_calls + 1
      return {
        open_async = function()
          return fuzzy_calls == 1 and "feature" or nil
        end,
      }
    end

    diff_actions.range({
      get_env = function()
        return nil
      end,
    })

    assert.is_true(vim.tbl_contains(options, "feature"))
  end)
end)
