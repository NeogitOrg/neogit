local async = require("plenary.async")
async.tests.add_to_env()

local git = require("neogit.lib.git")
local operations = require("neogit.operations")
local harness = require("tests.util.git_harness")
local in_prepared_repo = harness.in_prepared_repo

local CommitSelectViewBufferMock = require("tests.mocks.commit_select_buffer")
local input = require("tests.mocks.input")

local function act(normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys("", "x") -- flush typeahead
end

describe("rebase popup", function()
  local function test_reword(commit_to_reword, new_commit_message)
    local original_branch = git.branch.current()
    CommitSelectViewBufferMock.add(git.rev_parse.oid(commit_to_reword))
    input.values = { new_commit_message }
    act("rw<cr>")
    operations.wait("rebase_reword")
    assert.are.same(original_branch, git.branch.current())
    assert.are.same(new_commit_message, git.log.message("HEAD"))
  end

  it(
    "rebase to reword HEAD",
    in_prepared_repo(function()
      test_reword("HEAD", "foobar")
    end)
  )
  it(
    "rebase to reword HEAD~1",
    in_prepared_repo(function()
      test_reword("HEAD~1", "barbaz")
    end)
  )
  it(
    "rebase to reword HEAD~1 from log view",
    in_prepared_repo(function()
      act("ll") -- log branches and go down one commit
      operations.wait("log_current")
      test_reword("HEAD~1", "foo")
    end)
  )

  it(
    "rebase to reword HEAD fires NeogitRebase autocmd",
    in_prepared_repo(function()
      -- Arange
      local tx, rx = async.control.channel.oneshot()
      local group = vim.api.nvim_create_augroup("TestCustomNeogitEvents", { clear = true })
      vim.api.nvim_create_autocmd("User", {
        pattern = "NeogitRebase",
        group = group,
        callback = function()
          tx(true)
        end,
      })

      -- Timeout
      local timer = vim.loop.new_timer()
      timer:start(500, 0, function()
        tx(false)
      end)

      -- Act
      test_reword("HEAD", "foobar")

      -- Assert
      assert.are.same(true, rx())
    end)
  )
end)
