local git = require("neogit.lib.git")
local util = require("tests.util.util")

describe("lib.git.config", function()
  -- Neogit caches the repository root for the session, so the repository is only created once.
  local repo_dir
  local global_config
  local system_config
  local original_env = {
    GIT_CONFIG_GLOBAL = vim.env.GIT_CONFIG_GLOBAL,
    GIT_CONFIG_SYSTEM = vim.env.GIT_CONFIG_SYSTEM,
  }

  before_each(function()
    if not repo_dir then
      repo_dir = util.create_temp_dir("config-repo")
      local home_dir = util.create_temp_dir("config-home")
      global_config = home_dir .. "/gitconfig"
      system_config = home_dir .. "/system-gitconfig"

      vim.fn.writefile({ "[neogit]", "  systemOnly = yes" }, system_config)

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
    vim.env.GIT_CONFIG_SYSTEM = system_config
    vim.api.nvim_set_current_dir(repo_dir)
  end)

  after_each(function()
    for name, value in pairs(original_env) do
      vim.env[name] = value
    end
    vim.env.GIT_CONFIG_COUNT = nil
    vim.env.GIT_CONFIG_KEY_0 = nil
    vim.env.GIT_CONFIG_VALUE_0 = nil
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

  it("prefers local over global values", function()
    local entry = git.config.get("pull.rebase")
    assert.are.same("false", entry.value)
    assert.are.same("local", entry.scope)
  end)

  it("reads values only set in the system config", function()
    local entry = git.config.get("neogit.systemOnly")
    assert.are.same("yes", entry.value)
    assert.are.same("system", entry.scope)
  end)

  it("reads values passed via the environment", function()
    vim.env.GIT_CONFIG_COUNT = "1"
    vim.env.GIT_CONFIG_KEY_0 = "core.commentChar"
    vim.env.GIT_CONFIG_VALUE_0 = "%"

    local entry = git.config.get("core.commentChar")
    assert.are.same("%", entry.value)
    assert.are.same("command", entry.scope)
  end)

  it("returns an unset entry for missing keys", function()
    assert.True(git.config.get("neogit.doesNotExist"):is_unset())
  end)
end)
