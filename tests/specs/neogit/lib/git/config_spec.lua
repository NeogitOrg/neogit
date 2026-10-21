local eq = assert.are.same
local git = require("neogit.lib.git")
local git_harness = require("tests.util.git_harness")
local git_repo = require("neogit.lib.git.repository")
local util = require("tests.util.util")

describe("lib.git.config", function()
  local repo_dir

  before_each(function()
    if repo_dir then
      return
    end

    repo_dir = git_harness.prepare_repository()
    require("neogit").setup {}
    git_repo.instance(repo_dir)

    util.system { "git", "checkout", "-b", "Feature-X" }
    util.system { "git", "config", "branch.Feature-X.pushRemote", "origin" }
    util.system { "git", "config", "branch.master.pushRemote", "origin" }
  end)

  describe("#get_local", function()
    -- https://github.com/NeogitOrg/neogit/issues/1854
    it("preserves the case of the subsection", function()
      eq("origin", git.config.get_local("branch.Feature-X.pushRemote").value)
    end)

    it("does not match a subsection with different case", function()
      eq("", git.config.get_local("branch.feature-x.pushRemote").value)
    end)

    it("ignores the case of the section and variable name", function()
      eq("origin", git.config.get_local("BRANCH.master.PUSHREMOTE").value)
    end)
  end)

  describe("lib.git.branch #pushRemote", function()
    it("reads pushRemote for a branch with uppercase characters", function()
      eq("origin", git.branch.pushRemote("Feature-X"))
      eq("origin/Feature-X", git.branch.pushRemote_ref("Feature-X"))
    end)
  end)
end)
