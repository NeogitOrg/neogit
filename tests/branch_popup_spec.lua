require("plenary.async").tests.add_to_env()

local eq = assert.are.same
local operations = require("neogit.operations")

local harness = require("tests.git_harness")
local in_prepared_repo = harness.in_prepared_repo
local get_current_branch = harness.get_current_branch
local get_git_branches = harness.get_git_branches
local get_git_rev = harness.get_git_rev

local FuzzyFinderBuffer = require("tests.mocks.fuzzy_finder")
local input = require("tests.mocks.input")

local function act(normal_cmd)
  print("Feeding keys: ", normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys("", "x") -- flush typeahead
end

describe("branch popup", function()
  describe("actions", function()
    it(
      "can switch to another branch in the repository",
      in_prepared_repo(function()
        FuzzyFinderBuffer.value = "second-branch"
        act("bb<cr>")
        operations.wait("checkout_branch_revision")
        eq("second-branch", get_current_branch())
      end)
    )

    it(
      "can switch to another local branch in the repository",
      in_prepared_repo(function()
        FuzzyFinderBuffer.value = "second-branch"
        act("bl<cr>")
        operations.wait("checkout_branch_local")
        eq("second-branch", get_current_branch())
      end)
    )

    it(
      "can create a new branch",
      in_prepared_repo(function()
        input.value = "branch-from-test"
        act("bc<cr><cr>")
        operations.wait("checkout_create_branch")
        eq("branch-from-test", get_current_branch())
      end)
    )

    it(
      "can create a new branch without checking it out",
      in_prepared_repo(function()
        input.value = "branch-from-test-create"
        act("bn<cr><cr>")
        operations.wait("create_branch")
        eq("master", get_current_branch())
        eq(true, vim.tbl_contains(get_git_branches(), "branch-from-test-create"))
      end)
    )

    it(
      "can rename a branch",
      in_prepared_repo(function()
        FuzzyFinderBuffer.value = "second-branch"
        input.value = "second-branch-renamed"

        act("bm<cr><cr>")
        operations.wait("rename_branch")
        eq(true, vim.tbl_contains(get_git_branches(), "second-branch-renamed"))
        eq(false, vim.tbl_contains(get_git_branches(), "second-branch"))
      end)
    )

    it(
      "can reset a branch",
      in_prepared_repo(function()
        FuzzyFinderBuffer.value = "third-branch"

        eq("e2c2a1c0e5858a690c1dc13edc1fd5de103409d9", get_git_rev("HEAD"))
        act("bXy<cr>")
        operations.wait("reset_branch")
        eq("1e9b765da30ad45ef0b863470c73104bb7161e23", get_git_rev("HEAD"))
      end)
    )

    it(
      "can delete a branch",
      in_prepared_repo(function()
        FuzzyFinderBuffer.value = "third-branch"

        act("bD<cr>")
        operations.wait("delete_branch")
        eq(false, vim.tbl_contains(get_git_branches(), "third-branch"))
      end)
    )
  end)

  describe("variables", function()
    -- it("can change branch.*.description", in_prepared_repo(function()
    --   input.value = "branch description"
    --   act("bd<cr>")
    --   eq("branch description", harness.get_git_config("branch.master.description"))
    -- end))

    it(
      "can change branch.*.merge",
      in_prepared_repo(function()
        FuzzyFinderBuffer.value = "second-branch"

        eq("refs/heads/master", harness.get_git_config("branch.master.merge"))
        act("bu<cr>")
        eq("refs/heads/second-branch", harness.get_git_config("branch.master.merge"))
      end)
    )

    -- it(
    --   "can change branch.*.rebase",
    --   in_prepared_repo(function()
    --     eq("true", harness.get_git_config("branch.master.rebase"))
    --     act("br")
    --     eq("false", harness.get_git_config("branch.master.rebase"))
    --   end)
    -- )

    -- it(
    --   "can change branch.*.pushRemote",
    --   in_prepared_repo(function()
    --     act("bp")
    --   end)
    -- )
  end)
end)
