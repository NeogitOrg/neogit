local M = {}

local a = require("plenary.async")
local diffview_integration = require("neogit.integrations.diffview")
local Finder = require("neogit.lib.finder")
local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local notification = require("neogit.lib.notification")
local util = require("neogit.lib.util")

---@param popup table
local function close_popup_if_open(popup)
  if popup and type(popup.close) == "function" then
    popup:close()
  end
end

---@param popup table
---@param ... any diffview arguments
local function do_close_popup_and_open_diffview(popup, ...)
  close_popup_if_open(popup)
  diffview_integration.open(...)
end

---@param item_type string
---@param prompt_prefix string
---@param allow_multi? boolean
---@return table
local function create_finder(item_type, prompt_prefix, allow_multi)
  return Finder.create {
    item_type = item_type,
    prompt_prefix = prompt_prefix,
    allow_multi = allow_multi or false,
    refocus_status = false,
  }
end

---@param popup table
---@param item_type1 string
---@param prompt1 string
---@param item_type2 string
---@param prompt2 string
---@param on_both_selected function
local function prompt_for_item_pair_async(popup, item_type1, prompt1, item_type2, prompt2, on_both_selected)
  local finder1 = create_finder(item_type1, prompt1)

  local item1 = finder1:find_async()
  if not item1 or item1 == "" then
    close_popup_if_open(popup)
    return
  end

  local finder2 = create_finder(item_type2, prompt2)
  local item2 = finder2:find_async()
  if not item2 or item2 == "" then
    close_popup_if_open(popup)
    return
  end

  on_both_selected(item1, item2)
end

M.this = function(popup)
  if popup.state.env.section and popup.state.env.item then
    do_close_popup_and_open_diffview(popup, popup.state.env.section.name, popup.state.env.item.name, {
      only = true,
    })
  elseif popup.state.env.section then
    do_close_popup_and_open_diffview(popup, popup.state.env.section.name, nil, { only = true })
  else
    vim.notify("Neogit: No context for 'this' diff.", vim.log.levels.WARN)
    close_popup_if_open(popup)
  end
end

function M.worktree(popup)
  popup:close()
  diffview_integration.open("worktree")
end

function M.staged(popup)
  popup:close()
  diffview_integration.open("staged", nil, { only = true })
end

M.branch_range = a.void(function(popup)
  prompt_for_item_pair_async(
    popup,
    "branch",
    "Diff range FROM branch",
    "branch",
    "Diff range TO branch",
    function(branch1, branch2)
      local choices = { "&1. Cumulative (..)", "&2. Distinct (...)", "&3. Cancel" }
      local choice_num =
        input.get_choice("Select diff type for selected branches:", { values = choices, default = 1 })

      if choice_num == "1" then
        do_close_popup_and_open_diffview(popup, "range", branch1 .. ".." .. branch2)
      elseif choice_num == "2" then
        do_close_popup_and_open_diffview(popup, "range", branch1 .. "..." .. branch2)
      else
        close_popup_if_open(popup)
      end
    end
  )
end)

M.commit_range = a.void(function(popup)
  prompt_for_item_pair_async(
    popup,
    "commit",
    "Diff range FROM commit/ref",
    "commit",
    "Diff range TO commit/ref",
    function(commit1, commit2)
      do_close_popup_and_open_diffview(popup, "range", commit1 .. ".." .. commit2)
    end
  )
end)

M.tag_range = a.void(function(popup)
  prompt_for_item_pair_async(
    popup,
    "tag",
    "Diff range FROM tag",
    "tag",
    "Diff range TO tag",
    function(tag1, tag2)
      do_close_popup_and_open_diffview(popup, "range", tag1 .. ".." .. tag2)
    end
  )
end)

M.head_to_commit_ref = a.void(function(popup)
  local finder = create_finder("commit", "Diff HEAD to commit/ref")
  local commit_or_ref = finder:find_async()

  if commit_or_ref then
    do_close_popup_and_open_diffview(popup, "range", "HEAD.." .. commit_or_ref)
  else
    close_popup_if_open(popup)
  end
end)

M.stash = a.void(function(popup)
  local finder = create_finder("stash", "Select stash to diff")
  local stash_ref = finder:find_async()

  if stash_ref then
    do_close_popup_and_open_diffview(popup, "stashes", stash_ref)
  else
    close_popup_if_open(popup)
  end
end)

M.files = a.void(function(popup)
  local finder = create_finder("file", "Select files to diff", false)
  local file_to_diff = finder:find_async()

  if file_to_diff then
    local staged_files = git.repo.state.staged.items
    local unstaged_files = git.repo.state.unstaged.items

    local is_staged = false
    local is_unstaged = false

    for _, file in ipairs(staged_files) do
      if file.name == file_to_diff then
        is_staged = true
        break
      end
    end

    for _, file in ipairs(unstaged_files) do
      if file.name == file_to_diff then
        is_unstaged = true
        break
      end
    end

    -- Prefer unstaged if file is in both
    if is_unstaged then
      do_close_popup_and_open_diffview(popup, "unstaged", file_to_diff, { only = true })
    elseif is_staged then
      do_close_popup_and_open_diffview(popup, "staged", file_to_diff, { only = true })
    else
      -- Fallback to worktree
      do_close_popup_and_open_diffview(popup, "worktree", nil, { only = true })
    end
  else
    close_popup_if_open(popup)
  end
end)

M.custom_range = a.void(function(popup)
  prompt_for_item_pair_async(
    popup,
    "any_ref",
    "Diff range FROM (any ref)",
    "any_ref",
    "Diff range TO (any ref)",
    function(ref1, ref2)
      local choices = { "&1. Cumulative (..)", "&2. Distinct (...)", "&3. Cancel" }
      local choice_num =
        input.get_choice("Select diff type for selected refs:", { values = choices, default = 1 })

      if choice_num == "1" then
        do_close_popup_and_open_diffview(popup, "range", ref1 .. ".." .. ref2)
      elseif choice_num == "2" then
        do_close_popup_and_open_diffview(popup, "range", ref1 .. "..." .. ref2)
      else
        close_popup_if_open(popup)
      end
    end
  )
end)

M.paths = a.void(function(popup)
  local path_input_str = input.get_user_input("Enter path(s) to diff (space-separated, globs supported)", {
    completion = "dir",
    default = "./",
  })

  if not path_input_str or path_input_str == "" then
    close_popup_if_open(popup)
    return
  end

  local path_patterns = vim.split(path_input_str, "%s+")
  local all_files_to_diff = {}
  local found_any_files = false

  for _, pattern in ipairs(path_patterns) do
    if pattern ~= "" then
      local files_under_path_result =
        git.cli["ls-files"].args(pattern).call { hidden = true, ignore_error = true }

      if files_under_path_result.code == 0 and #files_under_path_result.stdout > 0 then
        found_any_files = true
        vim.list_extend(all_files_to_diff, files_under_path_result.stdout)
      end
    end
  end

  if not found_any_files then
    notification.warn("No tracked files found matching: " .. path_input_str)
    close_popup_if_open(popup)
    return
  end

  all_files_to_diff = util.deduplicate(all_files_to_diff)

  if #all_files_to_diff == 0 then
    notification.warn("No tracked files found matching: " .. path_input_str)
    close_popup_if_open(popup)
    return
  end

  local diff_args = { "HEAD", "--" }
  vim.list_extend(diff_args, all_files_to_diff)
  do_close_popup_and_open_diffview(popup, diff_args)
end)

function M.unstaged(popup)
  popup:close()
  diffview_integration.open("unstaged", nil, { only = true })
end

return M
