local async = require("plenary.async")
async.tests.add_to_env()

local git = require("neogit.lib.git")
local operations = require("neogit.operations")
local harness = require("tests.util.git_harness")
local util = require("tests.util.util")
local in_prepared_repo = harness.in_prepared_repo
local input = require("tests.mocks.input")
local FuzzyFinderBuffer = require("tests.mocks.fuzzy_finder")

local function act(normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys("", "x") -- flush typeahead
end

describe("stash popup", function()
  it(
    "create stash (both)",
    in_prepared_repo(function()
      act("Zz")
      operations.wait("stash_both")
      assert.are.same({ "stash@{0}: WIP on master: e2c2a1c b.txt" }, git.stash.list())
      assert.are.same("", harness.get_git_status("a.txt b.txt"))
    end)
  )

  -- FIXME: This is not working right now, Stashing index seems broken
  -- it(
  --   "create stash (index)",
  --   in_prepared_repo(function()
  --     act("Zi")
  --     operations.wait("stash_index")
  --     assert.are.same({ "stash@{0}: WIP on master: e2c2a1c b.txt" }, git.stash.list())
  --     assert.are.same("M a.txt", harness.get_git_status("a.txt b.txt"))
  --   end)
  -- )
  --

  it(
    "rename stash",
    in_prepared_repo(function()
      util.system("git stash")
      FuzzyFinderBuffer.value = { "stash@{0}" }
      input.values = { "Foobar" }

      act("Zm<cr>")
      operations.wait("stash_rename")

      assert.are.same({ "stash@{0}: Foobar" }, git.stash.list())
    end)
  )

  it(
    "rename stash doesn't drop stash if user presses ESC on message prompt",
    in_prepared_repo(function()
      util.system("git stash")
      FuzzyFinderBuffer.value = { "stash@{0}" }

      act("Zm<esc>")
      operations.wait("stash_rename")

      assert.are.same(1, #git.stash.list())
    end)
  )
end)
