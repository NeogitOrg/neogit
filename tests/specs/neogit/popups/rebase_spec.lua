local eq = assert.are.same
local rebase_actions = require("neogit.popups.rebase.actions")
local git = require("neogit.lib.git")

describe("rebase popup actions", function()
  local original_current, original_upstream, original_onto, original_fuzzy, original_refs

  before_each(function()
    original_current = git.branch.current
    original_upstream = git.branch.upstream
    original_onto = git.rebase.onto_branch
    original_fuzzy = require("neogit.buffers.fuzzy_finder").new
    original_refs = git.refs.list_branches
  end)

  after_each(function()
    git.branch.current = original_current
    git.branch.upstream = original_upstream
    git.rebase.onto_branch = original_onto
    require("neogit.buffers.fuzzy_finder").new = original_fuzzy
    git.refs.list_branches = original_refs
  end)

  it("onto_upstream resolves upstream and calls rebase without fuzzy finder", function()
    local fuzzy_finder_called = false
    local rebase_called_with = nil

    git.branch.current = function()
      return "feature-branch"
    end
    git.branch.upstream = function(branch)
      if branch == "feature-branch" then
        return "upstream-branch"
      end
      return nil
    end

    git.rebase.onto_branch = function(branch, args)
      rebase_called_with = branch
    end

    require("neogit.buffers.fuzzy_finder").new = function(...)
      fuzzy_finder_called = true
      return {
        open_async = function()
          return "wrong-branch"
        end,
      }
    end

    git.refs.list_branches = function()
      return {}
    end

    local popup_mock = {
      get_arguments = function()
        return { "--update-refs" }
      end,
    }

    rebase_actions.onto_upstream(popup_mock)

    eq(false, fuzzy_finder_called, "FuzzyFinderBuffer should not be called when an upstream is configured")
    eq(
      "upstream-branch",
      rebase_called_with,
      "git.rebase.onto_branch should be called with the exact upstream branch name"
    )
  end)

  it("onto_upstream opens fuzzy finder if upstream is NOT set", function()
    local fuzzy_finder_called = false
    local rebase_called_with = nil

    git.branch.current = function()
      return "feature-branch"
    end
    git.branch.upstream = function(branch)
      return nil
    end -- No upstream

    git.rebase.onto_branch = function(branch, args)
      rebase_called_with = branch
    end

    require("neogit.buffers.fuzzy_finder").new = function(...)
      fuzzy_finder_called = true
      return {
        open_async = function()
          return "fuzzy-selected-branch"
        end,
      }
    end

    git.refs.list_branches = function()
      return {}
    end

    local popup_mock = {
      get_arguments = function()
        return { "--update-refs" }
      end,
    }

    rebase_actions.onto_upstream(popup_mock)

    eq(true, fuzzy_finder_called, "FuzzyFinderBuffer should be called when an upstream is missing")
    eq(
      "fuzzy-selected-branch",
      rebase_called_with,
      "git.rebase.onto_branch should be called with fuzzy finder selection"
    )
  end)
end)
