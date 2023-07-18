local cli = require("neogit.lib.git.cli")
local M = {}

---Generates a patch that can be applied to index
---@param item any
---@param hunk any
---@param from any
---@param to any
---@param reverse boolean|nil
---@return string
function M.generate_patch(item, hunk, from, to, reverse)
  reverse = reverse or false
  from = from or 1
  to = to or hunk.diff_to - hunk.diff_from

  if from > to then
    from, to = to, from
  end
  from = from + hunk.diff_from
  to = to + hunk.diff_from

  local diff_content = {}
  local len_start = hunk.index_len
  local len_offset = 0

  -- + 1 skips the hunk header, since we construct that manually afterwards
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
  table.insert(diff_content, 1, string.format("+++ b/%s", item.name))
  table.insert(diff_content, 1, string.format("--- a/%s", item.name))
  table.insert(diff_content, "\n")

  return table.concat(diff_content, "\n")
end

---@param patch string diff generated with M.generate_patch
---@param opts table
---@return table
function M.apply(patch, opts)
  opts = opts or { reverse = false, cached = false, index = false }

  local cmd = cli.apply

  if opts.reverse then
    cmd = cmd.reverse
  end

  if opts.cached then
    cmd = cmd.cached
  end

  if opts.index then
    cmd = cmd.index
  end

  return cmd.with_patch(patch).call()
end

function M.add(files)
  return cli.add.files(unpack(files)).call()
end

function M.checkout(files)
  return cli.checkout.files(unpack(files)).call()
end

function M.reset(files)
  return cli.reset.files(unpack(files)).call()
end

-- Make sure the index is in sync as git-status skips it
-- Do this manually since the `cli` add --no-optional-locks
function M.update()
  require("neogit.process")
    .new({ cmd = { "git", "update-index", "-q", "--refresh" }, verbose = true })
    :spawn_async()
end

function M.register(meta)
  meta.update_index = function(state)
    state.index.timestamp = state.index_stat()
  end
end

return M
