local Path = require("plenary.path")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local Collection = require("neogit.lib.collection")
local logger = require("neogit.logger")

---@class StatusItem
---@field mode string
---@field diff Diff
---@field absolute_path string
---@field escaped_path string
---@field original_name string|nil
---@field file_mode {head: number, index: number, worktree: number}|nil
---@field submodule SubmoduleStatus|nil
---@field name string
---@field first number
---@field last number
---@field oid string|nil optional object id
---@field commit CommitLogEntry|nil optional object id
---@field folded boolean|nil
---@field hunks Hunk[]|nil

---@class SubmoduleStatus
---@field commit_changed boolean C
---@field has_tracked_changes boolean M
---@field has_untracked_changes boolean U

---@param status string
-- <sub>       A 4 character field describing the submodule state.
--             "N..." when the entry is not a submodule.
--             "S<c><m><u>" when the entry is a submodule.
--             <c> is "C" if the commit changed; otherwise ".".
--             <m> is "M" if it has tracked changes; otherwise ".".
--             <u> is "U" if there are untracked changes; otherwise ".".
local function parse_submodule_status(status)
  local a, b, c, d = status:match("(.)(.)(.)(.)")
  if a == "N" then
    return nil
  else
    return {
      commit_changed = b == "C",
      has_tracked_changes = c == "M",
      has_untracked_changes = d == "U",
    }
  end
end

---@return StatusItem
local function update_file(section, cwd, file, mode, name, original_name, file_mode, submodule)
  local absolute_path = Path:new(cwd, name):absolute()
  local escaped_path = vim.fn.fnameescape(vim.fn.fnamemodify(absolute_path, ":~:."))

  local item = { --[[@class StatusItem]]
    mode = mode,
    name = name,
    original_name = original_name,
    absolute_path = absolute_path,
    escaped_path = escaped_path,
    file_mode = file_mode,
    submodule = submodule,
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
        update_file("unstaged", state.worktree_root, old_files.unstaged_files[name], mode, name)
      )
    elseif kind == "?" then
      table.insert(
        state.untracked.items,
        update_file("untracked", state.worktree_root, old_files.untracked_files[rest], "?", rest)
      )
    elseif kind == "1" then
      local mode_staged, mode_unstaged, submodule, mH, mI, mW, hH, _, name = rest:match(match_1)
      local file_mode = { head = mH, index = mI, worktree = mW }
      local submodule = parse_submodule_status(submodule)

      if mode_staged ~= "." then
        if hH:match("^0+$") then
          mode_staged = "N"
        end

        table.insert(
          state.staged.items,
          update_file(
            "staged",
            state.worktree_root,
            old_files.staged_files[name],
            mode_staged,
            name,
            nil,
            file_mode,
            submodule
          )
        )
      end

      if mode_unstaged ~= "." then
        table.insert(
          state.unstaged.items,
          update_file(
            "unstaged",
            state.worktree_root,
            old_files.unstaged_files[name],
            mode_unstaged,
            name,
            nil,
            file_mode,
            submodule
          )
        )
      end
    elseif kind == "2" then
      local mode_staged, mode_unstaged, submodule, mH, mI, mW, _, _, _, name, orig_name = rest:match(match_2)
      local file_mode = { head = mH, index = mI, worktree = mW }
      local submodule = parse_submodule_status(submodule)

      if mode_staged ~= "." then
        table.insert(
          state.staged.items,
          update_file(
            "staged",
            state.worktree_root,
            old_files.staged_files[name],
            mode_staged,
            name,
            orig_name,
            file_mode,
            submodule
          )
        )
      end

      if mode_unstaged ~= "." then
        table.insert(
          state.unstaged.items,
          update_file(
            "unstaged",
            state.worktree_root,
            old_files.unstaged_files[name],
            mode_unstaged,
            name,
            orig_name,
            file_mode,
            submodule
          )
        )
      end
    end
  end
end

---@class NeogitGitStatus
local M = {}

---@param files string[]
function M.stage(files)
  git.cli.add.files(unpack(files)).call { await = true }
end

function M.stage_modified()
  git.cli.add.update.call { await = true }
end

function M.stage_untracked()
  local paths = util.map(git.repo.state.untracked.items, function(item)
    return item.escaped_path
  end)

  git.cli.add.files(unpack(paths)).call { await = true }
end

function M.stage_all()
  git.cli.add.all.call { await = true }
end

---@param files string[]
function M.unstage(files)
  git.cli.reset.files(unpack(files)).call { await = true }
end

function M.unstage_all()
  git.cli.reset.call { await = true }
end

---@return boolean
function M.is_dirty()
  return M.anything_unstaged() or M.anything_staged()
end

---@return boolean
function M.anything_staged()
  local output = git.cli.status.porcelain(2).call({ hidden = true }).stdout
  return vim.iter(output):any(function(line)
    return line:match("^%d [^%.]")
  end)
end

---@return boolean
function M.anything_unstaged()
  local output = git.cli.status.porcelain(2).call({ hidden = true }).stdout
  return vim.iter(output):any(function(line)
    return line:match("^%d %..")
  end)
end

---@return boolean
function M.any_unmerged()
  return vim.iter(git.repo.state.unstaged.items):any(function(item)
    return vim.tbl_contains({ "UU", "AA", "DU", "UD", "AU", "UA", "DD" }, item.mode)
  end)
end

M.register = function(meta)
  meta.update_status = update_status
end

return M
