require("plenary.async").tests.add_to_env()
local eq = assert.are.same
local operations = require("neogit.operations")
local harness = require("tests.util.git_harness")
local util = require("tests.util.util")
local in_prepared_repo = harness.in_prepared_repo

local status = require("neogit.status")
local state = require("neogit.lib.state")
local input = require("tests.mocks.input")

local function act(normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys("", "x") -- flush typeahead
  status.wait_on_current_operation()
end

describe("log popup", function()
  before_each(function()
    -- Reset all switches.
    state.setup()
    state._reset()
  end)

  after_each(function()
    -- Close log buffer.
    vim.fn.feedkeys("q", "x")
  end)

  it(
    "persists switches correctly",
    in_prepared_repo(function()
      -- Create a merge commit so that we can see graph markers in the log.
      util.system([[
        git checkout second-branch
        git reset --hard HEAD~
        git merge --no-ff master
      ]])

      act("ll")
      operations.wait("log_current")

      vim.fn.feedkeys("j", "x")
      -- Check for graph markers.
      eq([[        |\]], vim.api.nvim_get_current_line())
      vim.fn.feedkeys("q", "x")

      -- Open new log buffer with graph disabled.
      act("l-gl")
      operations.wait("log_current")
      vim.fn.feedkeys("j", "x")
      -- Check for absence of graph markers.
      eq("e2c2a1c  master origin/second-branch b.txt", vim.api.nvim_get_current_line())
      vim.fn.feedkeys("q", "x")

      -- Open new log buffer, remember_settings should persist that graph is disabled.
      act("ll")
      operations.wait("log_current")
      vim.fn.feedkeys("j", "x")
      -- Check for absence of graph markers.
      eq("e2c2a1c  master origin/second-branch b.txt", vim.api.nvim_get_current_line())
    end)
  )

  it(
    "respects decorate switch",
    in_prepared_repo(function()
      act("l-dl")
      operations.wait("log_current")
      eq("e2c2a1c * b.txt", vim.api.nvim_get_current_line())
    end)
  )

  it(
    "limits number of commits",
    in_prepared_repo(function()
      act("l=n<C-u>1<CR>l")
      operations.wait("log_current")
      vim.fn.feedkeys("G", "x")
      eq("e2c2a1c * master origin/second-branch b.txt", vim.api.nvim_get_current_line())
    end)
  )

  it(
    "limits commits based on author",
    in_prepared_repo(function()
      -- Create a new commit so that we can filter for it.
      util.system([[
        git config user.name "Person"
        git config user.mail "person@example.com"
        git commit --allow-empty -m "Empty commit"
      ]])
      act("l=APerson<CR>l")
      operations.wait("log_current")
      vim.fn.feedkeys("G", "x")
      assert.is_not.Nil(string.find(vim.api.nvim_get_current_line(), "Empty commit", 1, true))
    end)
  )

  it(
    "limits commits based on commit message",
    in_prepared_repo(function()
      act("l=Fa.txt<CR>l")
      operations.wait("log_current")
      vim.fn.feedkeys("G", "x")
      eq("d86fa0e * a.txt", vim.api.nvim_get_current_line())
    end)
  )

  it(
    "limits commits since date",
    in_prepared_repo(function()
      act("l=sFeb 8 2021<CR>l")
      operations.wait("log_current")
      vim.fn.feedkeys("G", "x")
      eq("e2c2a1c * master origin/second-branch b.txt", vim.api.nvim_get_current_line())
    end)
  )

  it(
    "limits commits until date",
    in_prepared_repo(function()
      act("l=uFeb 7 2021<CR>l")
      operations.wait("log_current")
      vim.fn.feedkeys("G", "x")
      eq("d86fa0e * a.txt", vim.api.nvim_get_current_line())
    end)
  )

  it(
    "limits based on changes",
    in_prepared_repo(function()
      input.values = { "text file" }
      act("l-Gl")
      operations.wait("log_current")
      vim.fn.feedkeys("G", "x")
      eq("d86fa0e * a.txt", vim.api.nvim_get_current_line())
    end)
  )

  it(
    "limits based on occurrences",
    in_prepared_repo(function()
      input.values = { "test file" }
      act("l-Sl")
      operations.wait("log_current")
      vim.fn.feedkeys("G", "x")
      eq("e2c2a1c * master origin/second-branch b.txt", vim.api.nvim_get_current_line())
    end)
  )

  it(
    "omits merge commits",
    in_prepared_repo(function()
      -- Create a merge commit so that we can filter it out.
      util.system([[
        git checkout second-branch
        git reset --hard HEAD~
        git merge --no-ff master
      ]])

      act("l=ml")
      operations.wait("log_current")
      eq("e2c2a1c * master origin/second-branch b.txt", vim.api.nvim_get_current_line())
    end)
  )

  it(
    "limits to commits from the first parent",
    in_prepared_repo(function()
      -- Create a merge commit so that we can filter to only show commits from the
      -- first parent of the merge commit.
      util.system([[
        git checkout second-branch
        git reset --hard HEAD~
        git merge --no-ff master
      ]])

      act("l=pl")
      operations.wait("log_current")
      vim.fn.feedkeys("j", "x")
      eq("d86fa0e * a.txt", vim.api.nvim_get_current_line())
    end)
  )
end)
