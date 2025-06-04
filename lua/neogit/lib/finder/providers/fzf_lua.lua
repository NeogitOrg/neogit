local config = require("neogit.config")
local git = require("neogit.lib.git")

local M = {}

---Check if fzf-lua is available
---@return boolean
function M.is_available()
  return config.check_integration("fzf_lua")
end

---Get fzf-lua module if available
---@return table|nil
local function get_fzf_lua()
  if M.is_available() then
    local fzf_ok, fzf_lua_mod = pcall(require, "fzf-lua")
    if fzf_ok then
      return fzf_lua_mod
    end
  end
  return nil
end

---Clean branch name from fzf-lua git_branches output
---@param name string
---@return string|nil
local function clean_branch_name(name)
  if not name or name == "" then
    return nil
  end
  if name:match("^%s*%*%s*%(HEAD detached .*%)") then
    return "HEAD"
  end
  name = name:gsub("^%s*%*%s*", "")
  name = (name:match("%s*->%s*(.+)$") or name):gsub("^%s+", ""):gsub("%s+$", "")
  return name ~= "" and name or nil
end

---Extract commit SHA from fzf-lua git_commits output
---@param entry_string string
---@return string|nil
local function extract_commit_sha_from_picker_entry(entry_string)
  if not entry_string or entry_string == "" then
    return nil
  end
  -- Extract the commit hash from the beginning of the line
  local hash = entry_string:match("^%s*([a-f0-9]+)")
  if hash and #hash >= 7 then
    return hash
  end
  -- Fallback to the original string if no hash found, but ensure it's not empty
  local trimmed = entry_string:gsub("^%s+", ""):gsub("%s+$", "")
  return trimmed ~= "" and trimmed or nil
end

---Process stash entry from fzf-lua git_stash output
---@param selected_entry_text string
---@return string|nil
local function process_stash_entry(selected_entry_text)
  if not selected_entry_text or selected_entry_text == "" then
    return nil
  end
  local stash_ref = selected_entry_text:match("^(stash@{%d+})")
  if stash_ref then
    return stash_ref
  end
  -- Fallback to the original string if it doesn't match the pattern, but ensure it's not empty
  local trimmed = selected_entry_text:gsub("^%s+", ""):gsub("%s+$", "")
  return trimmed ~= "" and trimmed or nil
end

---Sanitize tag name from fzf-lua git_tags output
---@param name string
---@return string|nil
local function sanitize_tag_name_for_picker(name)
  if not name or name == "" then
    return nil
  end
  local tag_name = name:match("^%s*([^%s]+)")
  if tag_name and tag_name ~= "" then
    return tag_name
  end
  -- Fallback to the original string if no match, but ensure it's not empty
  local trimmed = name:gsub("^%s+", ""):gsub("%s+$", "")
  return trimmed ~= "" and trimmed or nil
end

---Use specialized fzf-lua picker for branches
---@param opts table Finder options
---@param on_select fun(item: any|nil)
---@return boolean true if picker was used successfully
function M.pick_branch(opts, on_select)
  local fzf_lua = get_fzf_lua()
  if not fzf_lua or not fzf_lua.git_branches then
    return false
  end

  local function handle_selection(selected)
    if not selected then
      on_select(nil)
      return
    end

    if opts.allow_multi then
      if type(selected) ~= "table" or #selected == 0 then
        on_select(nil)
        return
      end
      local processed_items = {}
      for _, item in ipairs(selected) do
        local processed = clean_branch_name(item)
        if processed then
          table.insert(processed_items, processed)
        end
      end
      on_select(#processed_items > 0 and processed_items or nil)
    else
      local single_item = type(selected) == "table" and selected[1] or selected
      local processed = clean_branch_name(single_item)
      on_select(processed)
    end
  end

  fzf_lua.git_branches {
    prompt = string.format("%s> ", opts.prompt_prefix or "Select branch"),
    actions = {
      ["default"] = function(selected)
        vim.schedule(function()
          handle_selection(selected)
        end)
      end,
      ["ctrl-c"] = function()
        vim.schedule(function()
          on_select(nil)
        end)
      end,
      ["ctrl-q"] = function()
        vim.schedule(function()
          on_select(nil)
        end)
      end,
    },
  }

  return true
end

---Use specialized fzf-lua picker for commits
---@param opts table Finder options
---@param on_select fun(item: any|nil)
---@return boolean true if picker was used successfully
function M.pick_commit(opts, on_select)
  local fzf_lua = get_fzf_lua()
  if not fzf_lua or not fzf_lua.git_commits then
    return false
  end

  local function handle_selection(selected)
    if not selected then
      on_select(nil)
      return
    end

    if opts.allow_multi then
      if type(selected) ~= "table" or #selected == 0 then
        on_select(nil)
        return
      end
      local processed_items = {}
      for _, item in ipairs(selected) do
        local processed = extract_commit_sha_from_picker_entry(item)
        if processed then
          table.insert(processed_items, processed)
        end
      end
      on_select(#processed_items > 0 and processed_items or nil)
    else
      local single_item = type(selected) == "table" and selected[1] or selected
      local processed = extract_commit_sha_from_picker_entry(single_item)
      on_select(processed)
    end
  end

  fzf_lua.git_commits {
    prompt = string.format("%s> ", opts.prompt_prefix or "Select commit"),
    actions = {
      ["default"] = function(selected)
        vim.schedule(function()
          handle_selection(selected)
        end)
      end,
      ["ctrl-c"] = function()
        vim.schedule(function()
          on_select(nil)
        end)
      end,
      ["ctrl-q"] = function()
        vim.schedule(function()
          on_select(nil)
        end)
      end,
    },
  }

  return true
end

---Use specialized fzf-lua picker for tags
---@param opts table Finder options
---@param on_select fun(item: any|nil)
---@return boolean true if picker was used successfully
function M.pick_tag(opts, on_select)
  local fzf_lua = get_fzf_lua()
  if not fzf_lua or not fzf_lua.git_tags then
    return false
  end

  local function handle_selection(selected)
    if not selected then
      on_select(nil)
      return
    end

    if opts.allow_multi then
      if type(selected) ~= "table" or #selected == 0 then
        on_select(nil)
        return
      end
      local processed_items = {}
      for _, item in ipairs(selected) do
        local processed = sanitize_tag_name_for_picker(item)
        if processed then
          table.insert(processed_items, processed)
        end
      end
      on_select(#processed_items > 0 and processed_items or nil)
    else
      local single_item = type(selected) == "table" and selected[1] or selected
      local processed = sanitize_tag_name_for_picker(single_item)
      on_select(processed)
    end
  end

  fzf_lua.git_tags {
    prompt = string.format("%s> ", opts.prompt_prefix or "Select tag"),
    actions = {
      ["default"] = function(selected)
        vim.schedule(function()
          handle_selection(selected)
        end)
      end,
      ["ctrl-c"] = function()
        vim.schedule(function()
          on_select(nil)
        end)
      end,
      ["ctrl-q"] = function()
        vim.schedule(function()
          on_select(nil)
        end)
      end,
    },
  }

  return true
end

---Use specialized fzf-lua picker for stashes
---@param opts table Finder options
---@param on_select fun(item: any|nil)
---@return boolean true if picker was used successfully
function M.pick_stash(opts, on_select)
  local fzf_lua = get_fzf_lua()
  if not fzf_lua or not fzf_lua.git_stash then
    return false
  end

  local function handle_selection(selected)
    if not selected then
      on_select(nil)
      return
    end

    if opts.allow_multi then
      if type(selected) ~= "table" or #selected == 0 then
        on_select(nil)
        return
      end
      local processed_items = {}
      for _, item in ipairs(selected) do
        local processed = process_stash_entry(item)
        if processed then
          table.insert(processed_items, processed)
        end
      end
      on_select(#processed_items > 0 and processed_items or nil)
    else
      local single_item = type(selected) == "table" and selected[1] or selected
      local processed = process_stash_entry(single_item)
      on_select(processed)
    end
  end

  fzf_lua.git_stash {
    prompt = string.format("%s> ", opts.prompt_prefix or "Select stash"),
    actions = {
      ["default"] = function(selected)
        vim.schedule(function()
          handle_selection(selected)
        end)
      end,
      ["ctrl-c"] = function()
        vim.schedule(function()
          on_select(nil)
        end)
      end,
      ["ctrl-q"] = function()
        vim.schedule(function()
          on_select(nil)
        end)
      end,
    },
  }

  return true
end

---Use specialized fzf-lua picker for files (changed files only)
---@param opts table Finder options
---@param on_select fun(item: any|nil)
---@return boolean true if picker was used successfully
function M.pick_file(opts, on_select)
  local fzf_lua = get_fzf_lua()
  if not fzf_lua or not fzf_lua.git_status then
    return false
  end

  local function handle_selection(selected)
    if not selected then
      on_select(nil)
      return
    end

    local function extract_filename_from_status(status_line)
      -- git_status output format is typically: "status filename"
      -- Extract just the filename part
      local filename = status_line:match("%s+(.+)$") or status_line:match("^%S+%s+(.+)$") or status_line
      return filename
    end

    if opts.allow_multi then
      if type(selected) ~= "table" or #selected == 0 then
        on_select(nil)
        return
      end
      local processed_items = {}
      for _, item in ipairs(selected) do
        local processed = extract_filename_from_status(item)
        if processed then
          table.insert(processed_items, processed)
        end
      end
      on_select(#processed_items > 0 and processed_items or nil)
    else
      local single_item = type(selected) == "table" and selected[1] or selected
      local processed = extract_filename_from_status(single_item)
      on_select(processed)
    end
  end

  fzf_lua.git_status {
    prompt = string.format("%s> ", opts.prompt_prefix or "Select changed file"),
    actions = {
      ["default"] = function(selected)
        vim.schedule(function()
          handle_selection(selected)
        end)
      end,
      ["ctrl-c"] = function()
        vim.schedule(function()
          on_select(nil)
        end)
      end,
      ["ctrl-q"] = function()
        vim.schedule(function()
          on_select(nil)
        end)
      end,
    },
  }

  return true
end

---Use specialized fzf-lua picker for any_ref (combines branches, tags, commits)
---@param opts table Finder options
---@param on_select fun(item: any|nil)
---@return boolean true if picker was used successfully
function M.pick_any_ref(opts, on_select)
  local fzf_lua = get_fzf_lua()
  if not fzf_lua then
    return false
  end

  -- Create a combined list of refs and commits
  local function get_any_ref_data()
    local entries = {}

    -- Add symbolic refs like HEAD, ORIG_HEAD, etc.
    local heads = git.refs.heads()
    vim.list_extend(entries, heads)

    -- Add branches
    local branches = git.refs.list_branches()
    vim.list_extend(entries, branches)

    -- Add tags
    local tags = git.refs.list_tags()
    vim.list_extend(entries, tags)

    -- Add commits with proper formatting (sha + title) for better searchability
    local commits = git.log.list()
    for _, commit in ipairs(commits) do
      table.insert(entries, string.format("%s %s", commit.oid:sub(1, 7), commit.subject or ""))
    end

    return entries
  end

  local function handle_selection(selected)
    if not selected then
      on_select(nil)
      return
    end

    local function process_any_ref_item(item)
      if not item or item == "" then
        return nil
      end

      -- Check if it looks like a commit entry (starts with hex chars followed by space)
      local commit_hash = item:match("^%s*([a-f0-9]+)%s+")
      if commit_hash and #commit_hash >= 7 then
        return commit_hash
      end

      -- Otherwise, it's a branch/tag/symbolic ref, clean it up and use as-is
      local trimmed = item:gsub("^%s+", ""):gsub("%s+$", "")
      return trimmed ~= "" and trimmed or nil
    end

    if opts.allow_multi then
      if type(selected) ~= "table" or #selected == 0 then
        on_select(nil)
        return
      end
      local processed_items = {}
      for _, item in ipairs(selected) do
        local processed = process_any_ref_item(item)
        if processed then
          table.insert(processed_items, processed)
        end
      end
      on_select(#processed_items > 0 and processed_items or nil)
    else
      local single_item = type(selected) == "table" and selected[1] or selected
      local processed = process_any_ref_item(single_item)
      on_select(processed)
    end
  end

  fzf_lua.fzf_exec(get_any_ref_data(), {
    prompt = string.format("%s> ", opts.prompt_prefix or "Select any ref"),
    actions = {
      ["default"] = function(selected)
        vim.schedule(function()
          handle_selection(selected)
        end)
      end,
      ["ctrl-c"] = function()
        vim.schedule(function()
          on_select(nil)
        end)
      end,
      ["ctrl-q"] = function()
        vim.schedule(function()
          on_select(nil)
        end)
      end,
    },
  })

  return true
end

---Try to use specialized picker based on item_type
---@param item_type string
---@param opts table Finder options
---@param on_select fun(item: any|nil)
---@return boolean true if specialized picker was used
function M.try_specialized_picker(item_type, opts, on_select)
  if item_type == "branch" then
    return M.pick_branch(opts, on_select)
  elseif item_type == "commit" then
    return M.pick_commit(opts, on_select)
  elseif item_type == "tag" then
    return M.pick_tag(opts, on_select)
  elseif item_type == "any_ref" then
    return M.pick_any_ref(opts, on_select)
  elseif item_type == "stash" then
    return M.pick_stash(opts, on_select)
  elseif item_type == "file" then
    return M.pick_file(opts, on_select)
  end

  return false
end

return M
