local Path = require("plenary.path")
local Collection = require("neogit.lib.collection")

---@class File: StatusItem
---@field mode string
---@field has_diff boolean
---@field diff string[]
---@field absolute_path string

local function update_file(cwd, file, mode, name, original_name)
  local mt, diff, has_diff

  local absolute_path = Path:new(cwd, name):absolute()

  if file then
    mt = getmetatable(file)
    has_diff = file.has_diff

    if rawget(file, "diff") then
      diff = file.diff
    end
  end

  return setmetatable({
    mode = mode,
    name = name,
    original_name = original_name,
    has_diff = has_diff,
    diff = diff,
    absolute_path = absolute_path,
  }, mt or {})
end

local tag_pattern = "(.-)%-([0-9]+)%-g%x+$"
local match_kind = "(.) (.+)"
local match_u = "(..) (....) (%d+) (%d+) (%d+) (%d+) (%w+) (%w+) (%w+) (.+)"
local match_1 = "(.)(.) (....) (%d+) (%d+) (%d+) (%w+) (%w+) (.+)"
local match_2 = "(.)(.) (....) (%d+) (%d+) (%d+) (%w+) (%w+) (%a%d+) ([^\t]+)\t?(.+)"

local function update_status(state)
  local git = require("neogit.lib.git")
  local cwd = state.git_root

  local head = {}
  local upstream = { unmerged = { items = {} }, unpulled = { items = {} }, ref = nil }

  local untracked_files, unstaged_files, staged_files = {}, {}, {}
  local old_files_hash = {
    staged_files = Collection.new(state.staged.items or {}):key_by("name"),
    unstaged_files = Collection.new(state.unstaged.items or {}):key_by("name"),
    untracked_files = Collection.new(state.untracked.items or {}):key_by("name"),
  }

  local result = git.cli.status.null_separated.porcelain(2).branch.call { hidden = true }
  result = vim.split(result.stdout_raw[1], "\n")

  local collection = {}
  local line_nr = 1
  local prev_line = nil
  repeat
    local line = result[line_nr]
    if line:match("^[12u]%s[MTADRCU%s%.%?!][MTDRCU%s%.%?!]%s") or line:match("^[%?!#]%s") then
      table.insert(collection, line)
    elseif prev_line and prev_line:match("2%sR%.%s") then
      collection[#collection] = ("%s\t%s"):format(collection[#collection], line)
    end
    line_nr = line_nr + 1
    prev_line = line
  until line_nr > #result

  for _, l in ipairs(collection) do
    local header, value = l:match("# ([%w%.]+) (.+)")
    if header then
      if header == "branch.head" then
        head.branch = value
      elseif header == "branch.oid" then
        head.oid = value
        head.abbrev = git.rev_parse.abbreviate_commit(value)
      elseif header == "branch.upstream" then
        upstream.ref = value

        local commit = git.log.list({ value, "--max-count=1" }, nil, {}, true)[1]
        if commit then
          upstream.oid = commit.oid
          upstream.abbrev = git.rev_parse.abbreviate_commit(commit.oid)
        end

        local remote, branch = git.branch.parse_remote_branch(value)
        upstream.remote = remote
        upstream.branch = branch
      end
    else
      local kind, rest = l:match(match_kind)

      -- kinds:
      -- u = Unmerged
      -- 1 = Ordinary Entries
      -- 2 = Renamed/Copied Entries
      -- ? = Untracked
      -- ! = Ignored

      if kind == "u" then
        local mode, _, _, _, _, _, _, _, _, name = rest:match(match_u)

        table.insert(unstaged_files, update_file(cwd, old_files_hash.unstaged_files[name], mode, name))
      elseif kind == "?" then
        table.insert(untracked_files, update_file(cwd, old_files_hash.untracked_files[rest], nil, rest))
      elseif kind == "1" then
        local mode_staged, mode_unstaged, _, _, _, _, _, _, name = rest:match(match_1)

        if mode_staged ~= "." then
          table.insert(staged_files, update_file(cwd, old_files_hash.staged_files[name], mode_staged, name))
        end

        if mode_unstaged ~= "." then
          table.insert(
            unstaged_files,
            update_file(cwd, old_files_hash.unstaged_files[name], mode_unstaged, name)
          )
        end
      elseif kind == "2" then
        local mode_staged, mode_unstaged, _, _, _, _, _, _, _, name, orig_name = rest:match(match_2)

        if mode_staged ~= "." then
          table.insert(
            staged_files,
            update_file(cwd, old_files_hash.staged_files[name], mode_staged, name, orig_name)
          )
        end

        if mode_unstaged ~= "." then
          table.insert(
            unstaged_files,
            update_file(cwd, old_files_hash.unstaged_files[name], mode_unstaged, name, orig_name)
          )
        end
      end
    end
  end

  -- These are a bit hacky - because we can _partially_ refresh repo state (for now),
  -- some things need to be carried over here.
  if not state.head.branch or head.branch == state.head.branch then
    head.commit_message = state.head.commit_message
  end

  if not upstream.ref or upstream.ref == state.upstream.ref then
    upstream.commit_message = state.upstream.commit_message
  end

  if #state.upstream.unmerged.items > 0 then
    upstream.unmerged = state.upstream.unmerged
  end

  if #state.upstream.unpulled.items > 0 then
    upstream.unpulled = state.upstream.unpulled
  end

  local tag = git.cli.describe.long.tags.args("HEAD").call({ hidden = true, ignore_error = true }).stdout
  if #tag == 1 then
    local tag, distance = tostring(tag[1]):match(tag_pattern)
    if tag and distance then
      head.tag = { name = tag, distance = tonumber(distance) }
    else
      head.tag = { name = nil, distance = nil }
    end
  else
    head.tag = { name = nil, distance = nil }
  end

  state.head = head
  state.upstream = upstream
  state.untracked.items = untracked_files
  state.unstaged.items = unstaged_files
  state.staged.items = staged_files
end

local git = { cli = require("neogit.lib.git.cli") }
local status = {
  stage = function(files)
    git.cli.add.files(unpack(files)).call()
  end,
  stage_modified = function()
    git.cli.add.update.call()
  end,
  stage_all = function()
    git.cli.add.all.call()
  end,
  unstage = function(files)
    git.cli.reset.files(unpack(files)).call()
  end,
  unstage_all = function()
    git.cli.reset.call()
  end,
  is_dirty = function()
    local repo = require("neogit.lib.git.repository")
    return #repo.staged.items > 0 or #repo.unstaged.items > 0
  end,
  anything_staged = function()
    return #require("neogit.lib.git.repository").staged.items > 0
  end,
  anything_unstaged = function()
    return #require("neogit.lib.git.repository").unstaged.items > 0
  end,
}

status.register = function(meta)
  meta.update_status = update_status
end

return status
