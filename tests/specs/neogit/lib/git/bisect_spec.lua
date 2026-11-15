local eq = assert.are.same
local git_harness = require("tests.util.git_harness")
local util = require("tests.util.util")
local git_repo = require("neogit.lib.git.repository")

describe("lib.git.bisect", function()
  -- https://github.com/NeogitOrg/neogit/issues/2009
  it("ignores status lines in the bisect log", function()
    local dir = git_harness.prepare_repository()
    require("neogit").setup {}

    util.system { "git", "bisect", "start", "--no-checkout" }
    util.system { "git", "bisect", "bad", "HEAD" }
    util.system { "git", "bisect", "good", "HEAD~2" }

    local state = {}
    git_repo.instance(dir).lib.update_bisect_information(state)

    local actions = vim.tbl_map(function(item)
      return item.action
    end, state.bisect.items)
    eq({ "bad", "good" }, actions)
  end)
end)
