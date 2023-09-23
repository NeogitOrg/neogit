require("plenary.async").tests.add_to_env()
local eq = assert.are.same
local operations = require("neogit.operations")
local harness = require("tests.util.git_harness")
local util = require("tests.util.util")
local in_prepared_repo = harness.in_prepared_repo

local status = require("neogit.status")
local state = require("neogit.lib.state")

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
      eq("e2c2a1c * origin/second-branch master b.txt", vim.api.nvim_get_current_line())
    end)
  )
end)
