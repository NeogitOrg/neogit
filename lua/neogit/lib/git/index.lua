local git = require("neogit.lib.git")
local Path = require("plenary.path")
local util = require("neogit.lib.util")

---@class NeogitGitIndex
local M = {}

---Generates a patch that can be applied to index
---@param item any
---@param hunk Hunk
---@param from number
---@param to number
---@param reverse boolean|nil
---@return string
function M.generate_patch(item, hunk, from, to, reverse)
  reverse = reverse or false

  if not from and not to then
    from = hunk.diff_from + 1
    to = hunk.diff_to
  end

  assert(from <= to, string.format("from must be less than or equal to to %d %d", from, to))
  if from > to then
    from, to = to, from
  end

  local diff_content = {}
  local len_start = hunk.index_len
  local len_offset = 0

  -- + 1 skips the hunk header, since we construct that manually afterwards
  -- TODO: could use `hunk.lines` instead if this is only called with the `SelectedHunk` type
  for k = hunk.diff_from + 1, hunk.diff_to do
    local v = item.diff.lines[k]
    local operand, line = v:match("^([+ -])(.*)")

    if operand == "+" or operand == "-" then
      if from <= k and k <= to then
        len_offset = len_offset + (operand == "+" and 1 or -1)
        table.insert(diff_content, v)
      else
        -- If we want to apply the patch normally, we need to include every `-` line we skip as a normal line,
        -- since we want to keep that line.
        if not reverse then
          if operand == "-" then
            table.insert(diff_content, " " .. line)
          end
          -- If we want to apply the patch in reverse, we need to include every `+` line we skip as a normal line, since
          -- it's unchanged as far as the diff is concerned and should not be reversed.
          -- We also need to adapt the original line offset based on if we skip or not
        elseif reverse then
          if operand == "+" then
            table.insert(diff_content, " " .. line)
          end
          len_start = len_start + (operand == "-" and -1 or 1)
        end
      end
    else
      table.insert(diff_content, v)
    end
  end

  table.insert(
    diff_content,
    1,
    string.format("@@ -%d,%d +%d,%d @@", hunk.index_from, len_start, hunk.index_from, len_start + len_offset)
  )

  local worktree_root = git.repo.worktree_root

  assert(item.absolute_path, "Item is not a path")
  local path = Path:new(item.absolute_path):make_relative(worktree_root)

  table.insert(diff_content, 1, string.format("+++ b/%s", path))
  table.insert(diff_content, 1, string.format("--- a/%s", path))
  table.insert(diff_content, "\n")

  return table.concat(diff_content, "\n")
end

---@param patch string diff generated with M.generate_patch
---@param opts table
---@return table
function M.apply(patch, opts)
  opts = opts or { reverse = false, cached = false, index = false }

  local cmd = git.cli.apply

  if opts.reverse then
    cmd = cmd.reverse
  end

  if opts.cached then
    cmd = cmd.cached
  end

  if opts.index then
    cmd = cmd.index
  end

  return cmd.ignore_space_change.with_patch(patch).call { await = true }
end

function M.add(files)
  return git.cli.add.files(unpack(files)).call { await = true }
end

function M.checkout(files)
  return git.cli.checkout.files(unpack(files)).call { await = true }
end

function M.reset(files)
  return git.cli.reset.files(unpack(files)).call { await = true }
end

function M.reset_HEAD(...)
  return git.cli.reset.args("HEAD").arg_list({ ... }).call { await = true }
end

function M.checkout_unstaged()
  local items = util.map(git.repo.state.unstaged.items, function(item)
    return item.escaped_path
  end)

  return git.cli.checkout.files(unpack(items)).call { await = true }
end

---Creates a temp index from a revision and calls the provided function with the index path
---@param revision string Revision to create a temp index from
---@param fn fun(index: string): nil
function M.with_temp_index(revision, fn)
  assert(revision, "temp index requires a revision")
  assert(fn, "Pass a function to call with temp index")

  local tmp_index = Path:new(vim.uv.os_tmpdir(), ("index.neogit.%s"):format(revision))
  git.cli["read-tree"].index_output(tmp_index:absolute()).args(revision).call { hidden = true }
  assert(tmp_index:exists(), "Failed to create temp index")

  fn(tmp_index:absolute())

  tmp_index:rm()
  assert(not tmp_index:exists(), "Failed to remove temp index")
end

-- Make sure the index is in sync as git-status skips it
-- Do this manually since the `cli` add --no-optional-locks
function M.update()
  require("neogit.process")
    .new({
      cmd = { "git", "update-index", "-q", "--refresh" },
      on_error = function(_)
        return false
      end,
      suppress_console = true,
      git_hook = false,
      user_command = false,
    })
    :spawn_async()
end

local function timestamp()
  local now = os.date("!*t")
  return string.format("%s-%s-%sT%s.%s.%s", now.year, now.month, now.day, now.hour, now.min, now.sec)
end

-- https://gist.github.com/chx/3a694c2a077451e3d446f85546bb9278
-- Capture state of index as reflog entry
function M.create_backup()
  git.cli.add.update.call { hidden = true, await = true }
  git.cli.commit.message("Hard reset backup").call { hidden = true, await = true, pty = true }
  git.cli["update-ref"].args("refs/backups/" .. timestamp(), "HEAD").call { hidden = true, await = true }
  git.cli.reset.hard.args("HEAD~1").call { hidden = true, await = true }
end

return M
