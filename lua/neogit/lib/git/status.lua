local Path = require("plenary.path")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local Collection = require("neogit.lib.collection")
local logger = require("neogit.logger")

---@class StatusItem
---@field mode string
---@field diff string[]
---@field absolute_path string
---@field escaped_path string
---@field original_name string|nil

---@return StatusItem
local function update_file(section, cwd, file, mode, name, original_name)
  local absolute_path = Path:new(cwd, name):absolute()
  local escaped_path = vim.fn.fnameescape(vim.fn.fnamemodify(absolute_path, ":~:."))

  local item = { --[[@class StatusItem]]
    mode = mode,
    name = name,
    original_name = original_name,
    absolute_path = absolute_path,
    escaped_path = escaped_path,
  }

  if file and rawget(file, "diff") then
    item.diff = file.diff
  else
    git.diff.build(section, item)
  end

  return item
end

local match_kind = "(.) (.+)"
local match_u = "(..) (....) (%d+) (%d+) (%d+) (%d+) (%w+) (%w+) (%w+) (.+)"
local match_1 = "(.)(.) (....) (%d+) (%d+) (%d+) (%w+) (%w+) (.+)"
local match_2 = "(.)(.) (....) (%d+) (%d+) (%d+) (%w+) (%w+) (%a%d+) ([^\t]+)\t?(.+)"

local function item_collection(state, section, filter)
  local items = state[section].items or {}
  for _, item in ipairs(items) do
    if filter:accepts(section, item.name) then
      logger.debug(("[STATUS] Invalidating cached diff for: %s"):format(item.name))
      item.diff = nil
      git.diff.build(section, item)
    end
  end

  return Collection.new(items):key_by("name")
end

local function update_status(state, filter)
  local old_files = {
    staged_files = item_collection(state, "staged", filter),
    unstaged_files = item_collection(state, "unstaged", filter),
    untracked_files = item_collection(state, "untracked", filter),
  }

  state.staged.items = {}
  state.untracked.items = {}
  state.unstaged.items = {}

  local result = git.cli.status.null_separated.porcelain(2).call { hidden = true, remove_ansi = false }
  result = vim.split(result.stdout[1] or "", "\n")
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

  -- kinds:
  -- u = Unmerged
  -- 1 = Ordinary Entries
  -- 2 = Renamed/Copied Entries
  -- ? = Untracked
  -- ! = Ignored
  for _, l in ipairs(result) do
    local kind, rest = l:match(match_kind)
    if kind == "u" then
      local mode, _, _, _, _, _, _, _, _, name = rest:match(match_u)
      table.insert(
        state.unstaged.items,
        update_file("unstaged", state.git_root, old_files.unstaged_files[name], mode, name)
      )
    elseif kind == "?" then
      table.insert(
        state.untracked.items,
        update_file("untracked", state.git_root, old_files.untracked_files[rest], "?", rest)
      )
    elseif kind == "1" then
      local mode_staged, mode_unstaged, _, _, _, _, hH, _, name = rest:match(match_1)

      if mode_staged ~= "." then
        if hH:match("^0+$") then
          mode_staged = "N"
        end

        table.insert(
          state.staged.items,
          update_file("staged", state.git_root, old_files.staged_files[name], mode_staged, name)
        )
      end

      if mode_unstaged ~= "." then
        table.insert(
          state.unstaged.items,
          update_file("unstaged", state.git_root, old_files.unstaged_files[name], mode_unstaged, name)
        )
      end
    elseif kind == "2" then
      local mode_staged, mode_unstaged, _, _, _, _, _, _, _, name, orig_name = rest:match(match_2)

      if mode_staged ~= "." then
        table.insert(
          state.staged.items,
          update_file("staged", state.git_root, old_files.staged_files[name], mode_staged, name, orig_name)
        )
      end

      if mode_unstaged ~= "." then
        table.insert(
          state.unstaged.items,
          update_file(
            "unstaged",
            state.git_root,
            old_files.unstaged_files[name],
            mode_unstaged,
            name,
            orig_name
          )
        )
      end
    end
  end
end

---@class NeogitGitStatus
local status = {
  stage = function(files)
    git.cli.add.files(unpack(files)).call { await = true }
  end,
  stage_modified = function()
    git.cli.add.update.call { await = true }
  end,
  stage_untracked = function()
    local paths = util.map(git.repo.state.untracked.items, function(item)
      return item.escaped_path
    end)

    git.cli.add.files(unpack(paths)).call { await = true }
  end,
  stage_all = function()
    git.cli.add.all.call { await = true }
  end,
  unstage = function(files)
    git.cli.reset.files(unpack(files)).call { await = true }
  end,
  unstage_all = function()
    git.cli.reset.call { await = true }
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
