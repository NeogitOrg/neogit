local eq = assert.are.same
local actions = require("neogit.popups.commit.actions")
local async = require("neogit.lib.async")
local git = require("neogit.lib.git")
local util = require("tests.util.util")

local function run(...)
  return vim.trim(util.system { "git", ... })
end

describe("commit popup actions", function()
  local original_dir, repo_dir

  before_each(function()
    original_dir = vim.fn.getcwd()
    repo_dir = util.create_temp_dir("instant-fixup")
    vim.api.nvim_set_current_dir(repo_dir)
    run("init", "-b", "master")
    run("config", "user.name", "Neogit Test")
    run("config", "user.email", "test@neogit-test.test")
    run("commit", "--allow-empty", "-m", "initial")
    require("neogit").setup {}
  end)

  after_each(function()
    vim.api.nvim_set_current_dir(original_dir)
    vim.fn.delete(repo_dir, "rf")
  end)

  -- Fixing up a commit after an upstream merge must preserve that merge as its parent.
  it("instant fixup preserves the target commit's merge parent", function()
    run("checkout", "-b", "upstream-work")
    vim.fn.writefile({ "upstream change" }, "upstream.txt")
    run("add", "upstream.txt")
    run("commit", "-m", "upstream change")
    run("checkout", "master")
    run("merge", "--no-ff", "upstream-work", "-m", "merge upstream work")
    local merge = run("rev-parse", "HEAD")

    run("checkout", "-b", "feature")
    vim.fn.writefile({ "original" }, "feature.txt")
    run("add", "feature.txt")
    run("commit", "-m", "feature")
    local target = run("rev-parse", "HEAD")
    vim.fn.writefile({ "fixed" }, "feature.txt")
    run("add", "feature.txt")
    assert.is_true(git.repo:dispatch_refresh():wait(5000))

    async.util.block_on(function()
      actions.instant_fixup {
        state = { env = { commit = target } },
        get_arguments = function()
          return {}
        end,
      }
    end)

    eq(merge, run("rev-parse", "HEAD^"))
    eq("1", run("rev-list", "--count", "master..HEAD"))
    eq("fixed", run("show", "HEAD:feature.txt"))
    eq("upstream change", run("show", "HEAD:upstream.txt"))
    eq("", run("status", "--porcelain"))
  end)
end)
