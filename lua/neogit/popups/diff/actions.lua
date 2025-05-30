local M = {}

local config = require("neogit.config")
local diffview_integration = require("neogit.integrations.diffview")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local git = require("neogit.lib.git")
local a = require("plenary.async")
local input = require("neogit.lib.input")

local function get_fzf_lua()
  if config.check_integration("fzf_lua") then
    local fzf_ok, fzf_lua_mod = pcall(require, "fzf-lua")
    if fzf_ok then
      return fzf_lua_mod
    end
  end
  return nil
end

local function get_picker_selection(picker_raw_output)
  if type(picker_raw_output) == "table" and #picker_raw_output > 0 then
    return picker_raw_output[1]
  elseif type(picker_raw_output) == "string" then
    return picker_raw_output
  end
  return nil
end

local function clean_branch_name(name)
  if not name then
    return nil
  end
  name = name:match("%s*->%s*(.+)$") or name
  name = name:gsub("^%s*%*%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
  return name
end

local function close_popup_if_open(popup)
  if popup and type(popup.close) == "function" then
    popup:close()
  end
end

local function do_close_popup_and_open_diffview(popup, ...)
  close_popup_if_open(popup)
  diffview_integration.open(...)
end

local function get_refs_for_fallback_picker()
  local commits = git.log.list { "--max-count=200" }
  local formatted_commits = {}
  for _, commit_entry in ipairs(commits) do
    table.insert(
      formatted_commits,
      string.format("%s %s", commit_entry.oid:sub(1, 7), commit_entry.subject or "")
    )
  end
  return formatted_commits
end

local function extract_commit_sha_from_picker_entry(entry_string)
  if not entry_string then
    return nil
  end
  return entry_string:match("^%s*([a-f0-9]+)") or entry_string
end

--- Prompts the user to select item(s) using fzf-lua or a fallback FuzzyFinderBuffer.
--- @param popup table The popup object to close on cancel/completion.
--- @param fzf_lua table|nil The fzf-lua module, or nil to force fallback.
--- @param cfg table Configuration for the picker:
local function prompt_for_items_async(popup, fzf_lua, cfg)
  local item_processor = cfg.item_processor_fn or function(item)
    return item
  end
  local on_cancel_handler = cfg.on_cancel or function()
    close_popup_if_open(popup)
  end

  local function handle_selection(raw_selected_items)
    if not raw_selected_items then
      on_cancel_handler()
      return
    end

    if cfg.allow_multi then
      if type(raw_selected_items) ~= "table" or #raw_selected_items == 0 then
        on_cancel_handler()
        return
      end
      local processed_items = {}
      for _, item in ipairs(raw_selected_items) do
        local processed = item_processor(item)
        if processed ~= nil then
          table.insert(processed_items, processed)
        end
      end
      if #processed_items > 0 then
        cfg.on_select(processed_items)
      else
        on_cancel_handler()
      end
    else
      local single_item
      if type(raw_selected_items) == "table" then
        single_item = raw_selected_items[1]
      else
        single_item = raw_selected_items
      end

      local processed_single_item = single_item and item_processor(single_item) or nil
      if processed_single_item ~= nil then
        cfg.on_select(processed_single_item)
      else
        on_cancel_handler()
      end
    end
  end

  if fzf_lua and cfg.fzf_method_name then
    fzf_lua[cfg.fzf_method_name] {
      prompt = cfg.fzf_prompt,
      actions = {
        ["default"] = function(selected)
          handle_selection(selected)
        end,
        ["esc"] = on_cancel_handler,
      },
    }
  else
    local picker_opts = {
      prompt_prefix = cfg.fallback_prompt_prefix,
      refocus_status = false,
      allow_multi = cfg.allow_multi or false,
    }
    local raw_selection = FuzzyFinderBuffer.new(cfg.fallback_data_fn()):open_async(picker_opts)

    if cfg.allow_multi then
      handle_selection(raw_selection)
    else
      handle_selection(get_picker_selection(raw_selection))
    end
  end
end

--- Prompts the user to select two items sequentially using `prompt_for_items_async`.
--- @param popup table The popup object.
--- @param fzf_lua table|nil The fzf-lua module.
--- @param cfg1 table Picker configuration for the first item.
--- @param cfg2 table Picker configuration for the second item.
--- @param on_both_selected_fn function(item1, item2): Callback when both (non-nil processed) items are selected.
--- @param on_cancel_fn_outer (function, optional): Callback if any selection is cancelled or results in nil.
local function prompt_for_item_pair_async(popup, fzf_lua, cfg1, cfg2, on_both_selected_fn, on_cancel_fn_outer)
  local overall_cancel_handler = on_cancel_fn_outer or function()
    close_popup_if_open(popup)
  end

  cfg1.on_select = function(item1_processed)
    if item1_processed == nil then
      overall_cancel_handler()
      return
    end

    cfg2.on_select = function(item2_processed)
      if item2_processed == nil then
        overall_cancel_handler()
        return
      end
      on_both_selected_fn(item1_processed, item2_processed)
    end
    cfg2.on_cancel = overall_cancel_handler
    prompt_for_items_async(popup, fzf_lua, cfg2)
  end
  cfg1.on_cancel = overall_cancel_handler
  prompt_for_items_async(popup, fzf_lua, cfg1)
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

M.worktree = function(popup)
  do_close_popup_and_open_diffview(popup, "worktree")
end

M.staged = function(popup)
  do_close_popup_and_open_diffview(popup, "staged", nil, { only = true })
end

M.unstaged = function(popup)
  do_close_popup_and_open_diffview(popup, "unstaged", nil, { only = true })
end

M.branch_range = a.void(function(popup)
  local fzf = get_fzf_lua()
  local branch_picker_config = {
    fzf_method_name = "git_branches",
    fallback_data_fn = function()
      return git.refs.list_branches()
    end,
    item_processor_fn = clean_branch_name,
  }

  local cfg1 = vim.deepcopy(branch_picker_config)
  cfg1.fzf_prompt = "Diff range FROM branch> "
  cfg1.fallback_prompt_prefix = "Diff range FROM branch"

  local cfg2 = vim.deepcopy(branch_picker_config)
  cfg2.fzf_prompt = "Diff range TO branch> "
  cfg2.fallback_prompt_prefix = "Diff range TO branch"

  prompt_for_item_pair_async(popup, fzf, cfg1, cfg2, function(branch1, branch2)
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
  end)
end)

M.commit_range = a.void(function(popup)
  local fzf = get_fzf_lua()
  local commit_picker_config = {
    fzf_method_name = "git_commits",
    fallback_data_fn = get_refs_for_fallback_picker,
    item_processor_fn = extract_commit_sha_from_picker_entry,
  }

  local cfg1 = vim.deepcopy(commit_picker_config)
  cfg1.fzf_prompt = "Diff range FROM commit/ref> "
  cfg1.fallback_prompt_prefix = "Diff range FROM commit/ref"

  local cfg2 = vim.deepcopy(commit_picker_config)
  cfg2.fzf_prompt = "Diff range TO commit/ref> "
  cfg2.fallback_prompt_prefix = "Diff range TO commit/ref"

  prompt_for_item_pair_async(popup, fzf, cfg1, cfg2, function(commit_or_ref1, commit_or_ref2)
    do_close_popup_and_open_diffview(popup, "range", commit_or_ref1 .. ".." .. commit_or_ref2)
  end)
end)

M.head_to_commit_ref = a.void(function(popup)
  local fzf = get_fzf_lua()
  prompt_for_items_async(popup, fzf, {
    fzf_method_name = "git_commits",
    fzf_prompt = "Diff HEAD to commit/ref> ",
    fallback_data_fn = get_refs_for_fallback_picker,
    fallback_prompt_prefix = "Diff HEAD to commit/ref",
    item_processor_fn = extract_commit_sha_from_picker_entry,
    on_select = function(commit_or_ref)
      do_close_popup_and_open_diffview(popup, "range", "HEAD.." .. commit_or_ref)
    end,
  })
end)

M.stash = a.void(function(popup)
  local fzf = get_fzf_lua()

  local function process_stash_entry(selected_entry_text)
    if selected_entry_text then
      return selected_entry_text:match("^(stash@{%d+})")
    end
    return nil
  end

  prompt_for_items_async(popup, fzf, {
    fzf_method_name = "git_stash",
    fzf_prompt = "Diff stash> ",
    fallback_data_fn = function()
      return git.stash.list()
    end,
    fallback_prompt_prefix = "Select stash to diff",
    item_processor_fn = process_stash_entry,
    on_select = function(stash_ref)
      do_close_popup_and_open_diffview(popup, "stashes", stash_ref)
    end,
    on_cancel = function()
      vim.notify("Invalid stash selected or stash pattern not found.", vim.log.levels.WARN)
      close_popup_if_open(popup)
    end,
  })
end)

M.tag_range = a.void(function(popup)
  local fzf = get_fzf_lua()

  local function sanitize_tag_name_for_picker(name)
    if not name then
      return nil
    end
    return name:match("^%s*([^%s]+)") or name
  end

  local tag_picker_config = {
    fzf_method_name = "git_tags",
    fallback_data_fn = function()
      return git.refs.list_tags()
    end,
    item_processor_fn = sanitize_tag_name_for_picker,
  }

  local cfg1 = vim.deepcopy(tag_picker_config)
  cfg1.fzf_prompt = "Diff range FROM tag> "
  cfg1.fallback_prompt_prefix = "Diff range FROM tag"

  local cfg2 = vim.deepcopy(tag_picker_config)
  cfg2.fzf_prompt = "Diff range TO tag> "
  cfg2.fallback_prompt_prefix = "Diff range TO tag"

  prompt_for_item_pair_async(popup, fzf, cfg1, cfg2, function(tag1, tag2)
    do_close_popup_and_open_diffview(popup, "range", tag1 .. ".." .. tag2)
  end)
end)

M.files = a.void(function(popup)
  prompt_for_items_async(popup, nil, {
    fallback_data_fn = function()
      return git.files.all()
    end,
    fallback_prompt_prefix = "Select files to diff against HEAD",
    allow_multi = true,
    on_select = function(files_to_diff)
      if not files_to_diff or #files_to_diff == 0 then
        close_popup_if_open(popup)
        return
      end
      local diff_args = { "HEAD", "--" }
      vim.list_extend(diff_args, files_to_diff)
      do_close_popup_and_open_diffview(popup, diff_args)
    end,
    on_cancel = function()
      close_popup_if_open(popup)
    end,
  })
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

return M
