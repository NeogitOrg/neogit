local eq = assert.are.same
local git = require("neogit.lib.git")
local undo = require("neogit.lib.git.undo")

-- Builds the stdout the reflog reader expects: "<subject>\31<hash>" per line,
-- newest first.
local function reflog_lines(entries)
  return vim.tbl_map(function(entry)
    return entry.subject .. "\31" .. entry.hash
  end, entries)
end

describe("lib.git.undo", function()
  local original_reflog, original_reset, original_rebase, original_merge
  local reset_calls

  before_each(function()
    original_reflog = git.cli.reflog
    original_reset = git.cli.reset
    original_rebase = git.rebase.in_progress
    original_merge = git.merge.in_progress

    reset_calls = {}

    git.rebase.in_progress = function()
      return false
    end
    git.merge.in_progress = function()
      return false
    end

    -- Stub `git reset --soft <target>` so we can see where HEAD would move and
    -- with which reflog tag, without touching a real repository.
    git.cli.reset = {
      soft = {
        args = function(target)
          return {
            env = function(env)
              return {
                call = function()
                  table.insert(reset_calls, { target = target, action = env.GIT_REFLOG_ACTION })
                  return {
                    success = function()
                      return true
                    end,
                  }
                end,
              }
            end,
          }
        end,
      },
    }
  end)

  after_each(function()
    git.cli.reflog = original_reflog
    git.cli.reset = original_reset
    git.rebase.in_progress = original_rebase
    git.merge.in_progress = original_merge
  end)

  -- Stub HEAD's reflog with the given entries (newest first).
  local function stub_reflog(entries)
    git.cli.reflog = {
      show = {
        format = function()
          return {
            args = function()
              return {
                call = function()
                  return { stdout = reflog_lines(entries) }
                end,
              }
            end,
          }
        end,
      },
    }
  end

  describe("#undo", function()
    it("resets HEAD to the previous reflog position", function()
      stub_reflog {
        { subject = "commit: three", hash = "ccc" },
        { subject = "commit: two", hash = "bbb" },
        { subject = "commit: one", hash = "aaa" },
      }

      local ok = undo.undo()

      assert.True(ok)
      eq({ { target = "bbb", action = "[neogit: undo]" } }, reset_calls)
    end)

    it("skips its own undo entries when stepping back", function()
      stub_reflog {
        { subject = "[neogit: undo]: updating HEAD", hash = "bbb" },
        { subject = "commit: two", hash = "bbb" },
        { subject = "commit: one", hash = "aaa" },
      }

      undo.undo()

      eq("aaa", reset_calls[1].target)
    end)

    it("returns a message when there is nothing to undo", function()
      stub_reflog {}

      local ok, message = undo.undo()

      assert.False(ok)
      eq("Nothing to undo", message)
      eq({}, reset_calls)
    end)

    it("refuses to run while busy", function()
      git.rebase.in_progress = function()
        return true
      end

      local ok, message = undo.undo()

      assert.False(ok)
      eq("Can't undo while a rebase or merge is in progress", message)
      eq({}, reset_calls)
    end)
  end)

  describe("#redo", function()
    it("replays the last undo", function()
      stub_reflog {
        { subject = "[neogit: undo]: updating HEAD", hash = "bbb" },
        { subject = "commit: three", hash = "ccc" },
        { subject = "commit: two", hash = "bbb" },
      }

      local ok = undo.redo()

      assert.True(ok)
      eq({ { target = "ccc", action = "[neogit: redo]" } }, reset_calls)
    end)

    it("returns a message when the last action wasn't an undo", function()
      stub_reflog {
        { subject = "commit: three", hash = "ccc" },
        { subject = "commit: two", hash = "bbb" },
      }

      local ok, message = undo.redo()

      assert.False(ok)
      eq("Nothing to redo", message)
      eq({}, reset_calls)
    end)
  end)
end)
