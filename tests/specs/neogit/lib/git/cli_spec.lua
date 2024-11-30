local eq = assert.are.same
local git_cli = require("neogit.lib.git.cli")
local git_harness = require("tests.util.git_harness")
local in_prepared_repo = git_harness.in_prepared_repo

describe("git cli", function()
  describe("root detection", function()
    it(
      "finds the correct git root for a non symlinked directory",
      in_prepared_repo(function(root_dir)
        local detected_root_dir = git_cli.worktree_root(".")
        eq(detected_root_dir, root_dir)
      end)
    )

    it(
      "finds the correct git root for a symlinked directory without a .git dir in its upper paths",
      in_prepared_repo(function(root_dir)
        local git_dir = root_dir .. "/git-dir"
        local git_sub_dir = root_dir .. "/sub-dir"
        local symlink_dir = root_dir .. "/symlinked-dir"
        local cmd = string.format(
          [[
          mkdir -p %s/%s
          mv .git %s
          ln -s %s/%s %s
        ]],
          git_dir,
          git_sub_dir,
          git_dir,
          git_dir,
          git_sub_dir,
          symlink_dir
        )
        vim.fn.system(cmd)
        vim.api.nvim_set_current_dir(symlink_dir)

        local detected_root_dir = git_cli.worktree_root(".")
        eq(detected_root_dir, git_dir)
      end)
    )
  end)
end)
