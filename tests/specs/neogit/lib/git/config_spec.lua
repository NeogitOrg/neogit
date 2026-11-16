local git = require("neogit.lib.git")
local util = require("tests.util.util")

describe("lib.git.config", function()
  -- Neogit caches the repository root for the session, so the repository is only created once.
  local repo_dir
  local global_config
  local original_global_config = vim.env.GIT_CONFIG_GLOBAL

  before_each(function()
    if not repo_dir then
      repo_dir = util.create_temp_dir("config-repo")
      local home_dir = util.create_temp_dir("config-home")
      global_config = home_dir .. "/gitconfig"

      vim.fn.writefile({ "[core]", "  commentChar = @" }, home_dir .. "/included")
      vim.fn.writefile({
        "[pull]",
        "  rebase = true",
        string.format('[includeIf "gitdir:%s/"]', vim.fn.resolve(repo_dir)),
        string.format("  path = %s/included", home_dir),
      }, global_config)

      vim.api.nvim_set_current_dir(repo_dir)
      util.system { "git", "init", "--initial-branch", "master" }
      util.system { "git", "config", "pull.rebase", "false" }
    end

    vim.env.GIT_CONFIG_GLOBAL = global_config
    vim.api.nvim_set_current_dir(repo_dir)
  end)

  after_each(function()
    vim.env.GIT_CONFIG_GLOBAL = original_global_config
  end)

  it("reads global values", function()
    assert.are.same("true", git.config.get_global("pull.rebase").value)
  end)

  it("reads local values with local scope", function()
    local entry = git.config.get_local("pull.rebase")
    assert.are.same("false", entry.value)
    assert.are.same("local", entry.scope)
  end)

  it("follows includeIf in the global config", function()
    assert.are.same("@", git.config.get_global("core.commentChar").value)
    assert.are.same("@", git.config.get("core.commentChar").value)
  end)
end)
