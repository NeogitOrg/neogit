local eq = assert.are.same
local git_harness = require("tests.util.git_harness")
local in_prepared_repo = git_harness.in_prepared_repo
local git_repo = require("neogit.lib.git.repository")

describe("lib.git.instance", function()
  describe("getting instance", function()
    it(
      "creates cached git instance and returns it",
      in_prepared_repo(function(root_dir)
        local dir1 = git_repo.instance(root_dir).worktree_root
        local dir2 = git_repo.instance().worktree_root
        eq(dir1, dir2)
      end)
    )

    -- https://github.com/NeogitOrg/neogit/issues/1485
    it("switches to the cwd passed when opening a popup", function()
      local repo_a = git_harness.prepare_repository()
      require("neogit").setup {}
      git_repo.instance(repo_a)

      local repo_b = git_harness.prepare_repository()
      vim.api.nvim_set_current_dir(repo_a)

      require("neogit").open { "log", cwd = repo_b }
      vim.wait(2000, function()
        return vim.bo.filetype == "NeogitPopup"
      end)

      eq("NeogitPopup", vim.bo.filetype)
      eq(vim.fs.normalize(repo_b), vim.fs.normalize(git_repo.instance().worktree_root))
    end)
  end)
end)
