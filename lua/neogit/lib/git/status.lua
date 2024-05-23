local Path = require("plenary.path")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local Collection = require("neogit.lib.collection")

---@class StatusItem
---@field mode string
---@field diff string[]
---@field absolute_path string
---@field escaped_path string
---@field original_name string|nil

---@return StatusItem
local function update_file(cwd, file, mode, name, original_name)
  local absolute_path = Path:new(cwd, name):absolute()
  local escaped_path = vim.fn.fnameescape(vim.fn.fnamemodify(absolute_path, ":~:."))

  local mt, diff
  if file then
    mt = getmetatable(file)
    if rawget(file, "diff") then
      diff = file.diff
    end
  end

  return setmetatable({
    mode = mode,
    name = name,
    original_name = original_name,
    diff = diff,
    absolute_path = absolute_path,
    escaped_path = escaped_path,
  }, mt or {})
end

local tag_pattern = "(.-)%-([0-9]+)%-g%x+$"
local match_header = "# ([%w%.]+) (.+)"
local match_kind = "(.) (.+)"
local match_u = "(..) (....) (%d+) (%d+) (%d+) (%d+) (%w+) (%w+) (%w+) (.+)"
local match_1 = "(.)(.) (....) (%d+) (%d+) (%d+) (%w+) (%w+) (.+)"
local match_2 = "(.)(.) (....) (%d+) (%d+) (%d+) (%w+) (%w+) (%a%d+) ([^\t]+)\t?(.+)"

local function update_status(state)
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
  result = util.collect(result, function(line, collection)
    if line == "" then
      return
    end

    if line ~= "" and (line:match("^[12u]%s[%u%s%.%?!][%u%s%.%?!]%s") or line:match("^[%?!#]%s")) then
      table.insert(collection, line)
    else
      collection[#collection] = ("%s\t%s"):format(collection[#collection], line)
    end
  end)

  for _, l in ipairs(result) do
    local header, value = l:match(match_header)
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
        table.insert(untracked_files, update_file(cwd, old_files_hash.untracked_files[rest], "?", rest))
      elseif kind == "1" then
        local mode_staged, mode_unstaged, _, _, _, _, hH, _, name = rest:match(match_1)

        if mode_staged ~= "." then
          if hH:match("^0+$") then
            mode_staged = "N"
          end

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
      head.tag = { name = tag, distance = tonumber(distance), oid = git.rev_parse.oid(tag) }
    else
      head.tag = { name = nil, distance = nil, oid = nil }
    end
  else
    head.tag = { name = nil, distance = nil, oid = nil }
  end

  state.head = head
  state.upstream = upstream
  state.untracked.items = untracked_files
  state.unstaged.items = unstaged_files
  state.staged.items = staged_files
end

---@class NeogitGitStatus
local status = {
  stage = function(files)
    git.cli.add.files(unpack(files)).call()
  end,
  stage_modified = function()
    git.cli.add.update.call()
  end,
  stage_untracked = function()
    local paths = util.map(git.repo.state.untracked.items, function(item)
      return item.escaped_path
    end)

    git.cli.add.files(unpack(paths)).call()
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
    return #git.repo.state.staged.items > 0 or #git.repo.state.unstaged.items > 0
  end,
  anything_staged = function()
    return #git.repo.state.staged.items > 0
  end,
  anything_unstaged = function()
    return #git.repo.state.unstaged.items > 0
  end,
}

status.register = function(meta)
  meta.update_status = update_status
end

return status
