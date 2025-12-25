local M = {}

local git = require("neogit.lib.git")

local function notify_error(message)
  vim.schedule(function()
    vim.notify("codediff: " .. message, vim.log.levels.ERROR)
  end)
end

local function setup_on_close(opts)
  if opts.on_close then
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
      buffer = opts.on_close.handle,
      once = true,
      callback = opts.on_close.fn,
    })
  end
end

local function validate_codediff_api(codediff_git, view)
  local missing = {}

  for _, fn in ipairs { "get_status", "get_diff_revisions", "resolve_revision", "get_relative_path" } do
    if type(codediff_git[fn]) ~= "function" then
      table.insert(missing, "codediff.core.git." .. fn)
    end
  end

  if type(view.create) ~= "function" then
    table.insert(missing, "codediff.ui.view.create")
  end

  if #missing > 0 then
    notify_error("unsupported codediff.nvim API; missing: " .. table.concat(missing, ", "))
    return false
  end

  return true
end

local function get_codediff_modules()
  local ok_git, codediff_git = pcall(require, "codediff.core.git")
  if not ok_git then
    notify_error("failed to load codediff.core.git (" .. tostring(codediff_git) .. ")")
    return nil, nil
  end

  local ok_view, view = pcall(require, "codediff.ui.view")
  if not ok_view then
    notify_error("failed to load codediff.ui.view (" .. tostring(view) .. ")")
    return nil, nil
  end

  if not validate_codediff_api(codediff_git, view) then
    return nil, nil
  end

  return codediff_git, view
end

local function make_explorer_data(status_result, focus_file)
  local explorer_data = {
    status_result = status_result,
  }

  if type(focus_file) == "string" and focus_file ~= "" then
    explorer_data.focus_file = focus_file
  end

  return explorer_data
end

local function open_explorer(view, git_root, status_result, original_revision, modified_revision, focus_file)
  ---@type SessionConfig
  local session_config = {
    mode = "explorer",
    git_root = git_root,
    original_path = "",
    modified_path = "",
    original_revision = original_revision,
    modified_revision = modified_revision,
    explorer_data = make_explorer_data(status_result, focus_file),
  }

  view.create(session_config, "")
end

local function open_status_explorer(codediff_git, view, git_root, focus_file)
  codediff_git.get_status(git_root, function(err, status_result)
    if err then
      notify_error(err)
      return
    end

    vim.schedule(function()
      open_explorer(view, git_root, status_result, nil, nil, focus_file)
    end)
  end)
end

local function open_revision_explorer(codediff_git, view, git_root, original_revision, modified_revision)
  codediff_git.get_diff_revisions(original_revision, modified_revision, git_root, function(err, status_result)
    if err then
      notify_error(err)
      return
    end

    vim.schedule(function()
      open_explorer(view, git_root, status_result, original_revision, modified_revision)
    end)
  end)
end

local function open_single_ref_explorer(codediff_git, view, git_root, ref)
  if type(ref) ~= "string" or vim.trim(ref) == "" then
    notify_error("invalid reference")
    return
  end

  codediff_git.resolve_revision(ref, git_root, function(err_resolve, commit_hash)
    if err_resolve then
      notify_error(err_resolve)
      return
    end

    open_revision_explorer(codediff_git, view, git_root, commit_hash .. "^", commit_hash)
  end)
end

local function parse_range(item_name)
  if type(item_name) ~= "string" then
    return nil, "range must be a string"
  end

  local range = vim.trim(item_name)
  if range == "" then
    return nil, "range cannot be empty"
  end

  local base, target = range:match("^(.-)%.%.%.(.-)$")
  if base ~= nil then
    base = vim.trim(base)
    target = vim.trim(target)

    if base == "" then
      return nil, string.format("invalid triple-dot range '%s'", item_name)
    end

    return {
      kind = "triple",
      base = base,
      target = target ~= "" and target or "HEAD",
    }
  end

  local rev1, rev2 = range:match("^(.-)%.%.(.-)$")
  if rev1 == nil then
    return nil, string.format("invalid range '%s'", item_name)
  end

  rev1 = vim.trim(rev1)
  rev2 = vim.trim(rev2)

  if rev1 == "" or rev2 == "" then
    return nil, string.format("invalid double-dot range '%s'", item_name)
  end

  return {
    kind = "double",
    rev1 = rev1,
    rev2 = rev2,
  }, nil
end

local function open_range_explorer(codediff_git, view, git_root, item_name)
  local parsed_range, parse_err = parse_range(item_name)
  if not parsed_range then
    notify_error(parse_err)
    return
  end

  if parsed_range.kind == "double" then
    open_revision_explorer(codediff_git, view, git_root, parsed_range.rev1, parsed_range.rev2)
    return
  end

  if type(codediff_git.get_merge_base) ~= "function" then
    notify_error("triple-dot ranges require codediff.core.git.get_merge_base")
    return
  end

  codediff_git.get_merge_base(
    parsed_range.base,
    parsed_range.target,
    git_root,
    function(err_mb, merge_base_hash)
      if err_mb then
        notify_error(err_mb)
        return
      end

      codediff_git.resolve_revision(parsed_range.target, git_root, function(err_target, target_hash)
        if err_target then
          notify_error(err_target)
          return
        end

        open_revision_explorer(codediff_git, view, git_root, merge_base_hash, target_hash)
      end)
    end
  )
end

local function get_focus_file(section_name, item_name)
  if type(item_name) ~= "string" then
    return nil
  end

  if
    section_name == "staged"
    or section_name == "unstaged"
    or section_name == "merge"
    or section_name == "worktree"
  then
    return item_name
  end

  return nil
end

local function normalize_ref(ref)
  if type(ref) ~= "string" then
    return ref
  end

  local trimmed = vim.trim(ref)
  local stash_ref = trimmed:match("(stash@{%d+})")
  if stash_ref then
    return stash_ref
  end

  return trimmed
end

local function extract_commit(item_name)
  if type(item_name) ~= "string" then
    return nil
  end

  local trimmed = vim.trim(item_name)
  local from_start = trimmed:match("^([0-9a-fA-F]+)")
  if from_start then
    return from_start
  end

  return trimmed:match("([0-9a-fA-F][0-9a-fA-F]+)")
end

local function get_conflict_revisions()
  local original_revision = ":3"
  local modified_revision = ":2"

  local ok_config, codediff_config = pcall(require, "codediff.config")
  if not ok_config then
    return original_revision, modified_revision
  end

  local diff_options = codediff_config.options and codediff_config.options.diff or {}
  if diff_options.conflict_ours_position == "left" then
    original_revision = ":2"
    modified_revision = ":3"
  end

  return original_revision, modified_revision
end

---@param section_name string
---@param item_name    string|string[]|nil
---@param opts         table|nil
function M.open(section_name, item_name, opts)
  opts = opts or {}

  local codediff_git, view = get_codediff_modules()
  if not codediff_git or not view then
    return
  end

  setup_on_close(opts)

  local git_root = git.repo.worktree_root
  if type(git_root) ~= "string" or git_root == "" then
    notify_error("git root is unavailable")
    return
  end

  -- Map Neogit sections to codediff operations
  -- selene: allow(if_same_then_else)
  if section_name == "staged" or section_name == "unstaged" or section_name == "merge" then
    open_status_explorer(codediff_git, view, git_root, get_focus_file(section_name, item_name))
  elseif
    section_name == "recent"
    or section_name == "log"
    or (section_name and section_name:match("unmerged$"))
  then
    local rev1, rev2

    if type(item_name) == "table" then
      rev1 = normalize_ref(item_name[1])
      rev2 = normalize_ref(item_name[#item_name])

      if type(rev1) ~= "string" or rev1 == "" or type(rev2) ~= "string" or rev2 == "" then
        notify_error("invalid commit range selection")
        return
      end
    else
      local commit = extract_commit(item_name)
      if not commit then
        notify_error("could not extract commit from selection")
        return
      end

      rev1 = commit .. "^"
      rev2 = commit
    end

    open_revision_explorer(codediff_git, view, git_root, rev1, rev2)
  elseif section_name == "range" and item_name then
    open_range_explorer(codediff_git, view, git_root, item_name)
  elseif (section_name == "stashes" or section_name == "commit") and item_name then
    open_single_ref_explorer(codediff_git, view, git_root, normalize_ref(item_name))
  elseif section_name == "conflict" then
    if item_name then
      local file_path = type(item_name) == "string" and item_name or item_name[1]
      if not file_path then
        notify_error("missing conflict file path")
        return
      end

      local relative_path = codediff_git.get_relative_path(git_root .. "/" .. file_path, git_root)
      local filetype = vim.filetype.match { filename = file_path } or ""
      local original_revision, modified_revision = get_conflict_revisions()

      ---@type SessionConfig
      local session_config = {
        mode = "standalone",
        git_root = git_root,
        original_path = relative_path,
        modified_path = relative_path,
        original_revision = original_revision,
        modified_revision = modified_revision,
        conflict = true,
      }
      view.create(session_config, filetype)
    else
      open_status_explorer(codediff_git, view, git_root)
    end
  elseif section_name == "worktree" or (section_name == nil and item_name == nil) then
    open_status_explorer(codediff_git, view, git_root, get_focus_file(section_name, item_name))
  elseif section_name == nil and item_name ~= nil then
    open_single_ref_explorer(codediff_git, view, git_root, normalize_ref(item_name))
  end
end

return M
