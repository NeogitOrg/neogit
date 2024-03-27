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
  before_each(function()
    vim.fn.feedkeys("q", "x")
    CommitSelectViewBufferMock.clear()
  end)

  local function test_reword(commit_to_reword, new_commit_message, selected)
    local original_branch = git.branch.current()
    if selected == false then
      CommitSelectViewBufferMock.add(git.rev_parse.oid(commit_to_reword))
    end
    input.values = { new_commit_message }
    act("rw<cr>")
    operations.wait("rebase_reword")
    assert.are.same(original_branch, git.branch.current())
    assert.are.same(new_commit_message, git.log.message(commit_to_reword))
  end

  local function test_modify(commit_to_modify, selected)
    local new_head = git.rev_parse.oid(commit_to_modify)
    if selected == false then
      CommitSelectViewBufferMock.add(git.rev_parse.oid(commit_to_modify))
    end
    act("rm<cr>")
    operations.wait("rebase_modify")
    assert.are.same(new_head, git.rev_parse.oid("HEAD"))
  end

  local function test_drop(commit_to_drop, selected)
    local dropped_commit = git.rev_parse.oid(commit_to_drop)
    if selected == false then
      CommitSelectViewBufferMock.add(git.rev_parse.oid(commit_to_drop))
    end
    act("rd<cr>")
    operations.wait("rebase_drop")
    assert.is_not.same(dropped_commit, git.rev_parse.oid(commit_to_drop))
  end

  it(
    "rebase to drop HEAD",
    in_prepared_repo(function()
      test_drop("HEAD", false)
    end)
  )
  it(
    "rebase to drop HEAD~1",
    in_prepared_repo(function()
      test_drop("HEAD~1", false)
    end)
  )
  it(
    "rebase to drop HEAD~1 from log view",
    in_prepared_repo(function()
      act("ll") -- log commits
      operations.wait("log_current")
      act("j") -- go down one commit
      test_drop("HEAD~1", true)
    end)
  )

  it(
    "rebase to reword HEAD",
    in_prepared_repo(function()
      test_reword("HEAD", "foobar", false)
    end)
  )
  it(
    "rebase to reword HEAD~1",
    in_prepared_repo(function()
      test_reword("HEAD~1", "barbaz", false)
    end)
  )
  it(
    "rebase to reword HEAD~1 from log view",
    in_prepared_repo(function()
      act("ll") -- log commits
      operations.wait("log_current")
      act("j") -- go down one commit
      test_reword("HEAD~1", "foo", true)
    end)
  )

  it(
    "rebase to modify HEAD",
    in_prepared_repo(function()
      test_modify("HEAD", false)
    end)
  )
  it(
    "rebase to modify HEAD~1",
    in_prepared_repo(function()
      test_modify("HEAD~1", false)
    end)
  )
  it(
    "rebase to modify HEAD~1 from log view",
    in_prepared_repo(function()
      act("ll")
      operations.wait("log_current")
      act("j")
      test_modify("HEAD~1", true)
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
      test_reword("HEAD", "foobar", false)

      -- Assert
      assert.are.same(true, rx())
    end)
  )

  it(
    "rebase to modify HEAD fires NeogitRebase autocmd",
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
      test_modify("HEAD", false)

      -- Assert
      assert.are.same(true, rx())
    end)
  )
end)
