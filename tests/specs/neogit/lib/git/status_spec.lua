local git = require("neogit.lib.git")
local Repo = require("neogit.lib.git.repository")
local runner = require("neogit.runner")
local a = require("neogit.lib.async")

describe("shared refresh status", function()
  local root, repo, saved_repo, saved_call, status_calls

  local function command(...)
    local result = vim.system({ "git", "-C", root, ... }, { text = true }):wait()
    assert.are.equal(0, result.code, result.stderr)
    return vim.trim(result.stdout)
  end

  local function refresh()
    local done = false
    repo:dispatch_refresh {
      source = "test",
      callback = function()
        done = true
      end,
    }
    assert.is_true(vim.wait(10000, function()
      return done
    end))
  end

  before_each(function()
    require("neogit").setup {}
    root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    command("init", "-b", "main")
    command("config", "user.name", "Neogit Test")
    command("config", "user.email", "test@neogit-test.test")
    saved_repo = rawget(git, "repo")
    repo = Repo.new(root)
    git.repo = repo
    status_calls = 0
    saved_call = runner.call
    runner.call = function(process, opts)
      if vim.tbl_contains(process.cmd, "status") then
        status_calls = status_calls + 1
      end
      return saved_call(process, opts)
    end
  end)

  after_each(function()
    runner.call = saved_call
    git.repo = saved_repo
    vim.fn.delete(root, "rf")
  end)

  it("reads branch and file status once and fetches fresh data on the next refresh", function()
    vim.fn.writefile({ "initial", "unchanged line", "another unchanged line" }, root .. "/tracked.txt")
    command("add", ".")
    command("commit", "-m", "initial")
    command("update-ref", "refs/remotes/origin/main", "HEAD")
    command("config", "remote.origin.url", root)
    command("config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*")
    command("branch", "--set-upstream-to=origin/main", "main")
    command("mv", "tracked.txt", "renamed.txt")
    vim.fn.writefile({ "modified", "unchanged line", "another unchanged line" }, root .. "/renamed.txt")
    vim.fn.writefile({ "untracked" }, root .. "/untracked.txt")

    refresh()
    assert.are.equal(1, status_calls)
    assert.are.equal("main", repo.state.head.branch)
    assert.are.equal(command("rev-parse", "HEAD"), repo.state.head.oid)
    assert.is_false(repo.state.head.detached)
    assert.are.equal("origin/main", repo.state.upstream.ref)
    assert.are.equal("renamed.txt", repo.state.staged.items[1].name)
    assert.are.equal("tracked.txt", repo.state.staged.items[1].original_name)
    assert.are.equal("renamed.txt", repo.state.unstaged.items[1].name)
    assert.are.equal("untracked.txt", repo.state.untracked.items[1].name)

    command("add", ".")
    refresh()
    assert.are.equal(2, status_calls)
    assert.are.equal(0, #repo.state.unstaged.items)
    assert.are.equal(0, #repo.state.untracked.items)
    assert.are.equal(2, #repo.state.staged.items)
  end)

  it("handles an unborn branch", function()
    refresh()
    assert.are.equal(1, status_calls)
    assert.are.equal("main", repo.state.head.branch)
    assert.are.equal("(initial)", repo.state.head.oid)
    assert.is_false(repo.state.head.detached)
    assert.is_nil(repo.state.upstream.ref)
  end)

  it("handles a detached HEAD", function()
    command("commit", "--allow-empty", "-m", "initial")
    command("checkout", "--detach")
    refresh()
    assert.are.equal(1, status_calls)
    assert.is_true(repo.state.head.detached)
    assert.are.equal(command("rev-parse", "HEAD"), repo.state.head.oid)
    assert.is_nil(repo.state.upstream.ref)
  end)

  it("cancels module tasks when a newer refresh starts", function()
    local started, cancelled = 0, 0
    repo.lib = {
      slow = a.wrap(function(_, _, _, callback)
        started = started + 1
        local timer = vim.defer_fn(callback, 100)
        return function()
          cancelled = cancelled + 1
          timer:stop()
          timer:close()
        end
      end, 4),
    }
    repo:dispatch_refresh()
    assert.is_true(vim.wait(10000, function()
      return started == 1
    end))
    refresh()
    assert.are.equal(1, cancelled)
    assert.are.equal(2, started)
    assert.are.equal(2, status_calls)
  end)
end)
