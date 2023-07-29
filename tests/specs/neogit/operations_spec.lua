require("plenary.async").tests.add_to_env()
local eq = assert.are.same
local operations = require("neogit.operations")
local harness = require("tests.util.git_harness")
local in_prepared_repo = harness.in_prepared_repo
local get_current_branch = harness.get_current_branch
local get_git_branches = harness.get_git_branches

local FuzzyFinderBuffer = require("tests.mocks.fuzzy_finder")
local status = require("neogit.status")
local input = require("tests.mocks.input")

local function act(normal_cmd)
  print("Feeding keys: ", normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys("", "x") -- flush typeahead
  status.wait_on_current_operation()
end

describe("branch popup", function()
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
      assert.True(vim.tbl_contains(get_git_branches(), "branch-from-test-create"))
    end)
  )
end)
