local config = require("neogit.config")

describe("git_executable configuration", function()
  before_each(function()
    config.values = config.get_default_values()
  end)

  describe("default configuration", function()
    it("should default to 'git'", function()
      assert.are.equal("git", config.get_git_executable())
    end)
  end)

  describe("custom git_executable", function()
    it("should accept a custom git executable path", function()
      config.setup { git_executable = "/usr/local/bin/git" }
      assert.are.equal("/usr/local/bin/git", config.get_git_executable())
    end)

    it("should accept a git wrapper script", function()
      config.setup { git_executable = "/path/to/custom-git" }
      assert.are.equal("/path/to/custom-git", config.get_git_executable())
    end)
  end)

  describe("validation", function()
    it("should return invalid when git_executable is not a string", function()
      config.values.git_executable = 123
      assert.True(vim.tbl_count(config.validate_config()) ~= 0)
    end)

    it("should return valid when git_executable is a string", function()
      config.values.git_executable = "/custom/git"
      assert.True(vim.tbl_count(config.validate_config()) == 0)
    end)

    it("should return valid for default git_executable", function()
      config.values.git_executable = "git"
      assert.True(vim.tbl_count(config.validate_config()) == 0)
    end)
  end)
end)
