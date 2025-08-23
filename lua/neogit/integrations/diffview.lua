local M = {}

local Rev = require("diffview.vcs.adapters.git.rev").GitRev
local RevType = require("diffview.vcs.rev").RevType
local CDiffView = require("diffview.api.views.diff.diff_view").CDiffView
local dv_lib = require("diffview.lib")
local dv_utils = require("diffview.utils")

local Watcher = require("neogit.watcher")
local git = require("neogit.lib.git")
local a = require("plenary.async")

local function get_local_diff_view(section_name, item_name, opts)
  local left = Rev(RevType.STAGE)
  local right = Rev(RevType.LOCAL)

  local function update_files()
    local files = {}

    local sections = {}

    -- all conflict modes (but I don't know how to generate UA/AU)
    local conflict_modes = { "UU", "UD", "DU", "AA", "UA", "AU" }

    -- merge section gets both
    if section_name == "unstaged" or section_name == "merge" then
      sections.conflicting = {
        items = vim.tbl_filter(function(item)
          return vim.tbl_contains(conflict_modes, item.mode) and item
        end, git.repo.state.unstaged.items),
      }
      sections.working = {
        items = vim.tbl_filter(function(item)
          return not vim.tbl_contains(conflict_modes, item.mode) and item
        end, git.repo.state.unstaged.items),
      }
    end

    if section_name == "staged" or section_name == "merge" then
      sections.staged = git.repo.state.staged
    end

    for kind, section in pairs(sections) do
      files[kind] = {}

      for idx, item in ipairs(section.items) do
        local file = {
          path = item.name,
          status = item.mode and item.mode:sub(1, 1),
          stats = (item.diff and item.diff.stats) and {
            additions = item.diff.stats.additions or 0,
            deletions = item.diff.stats.deletions or 0,
          } or nil,
          left_null = vim.tbl_contains({ "A", "?" }, item.mode),
          right_null = false,
          selected = (item_name and item.name == item_name) or (not item_name and idx == 1),
        }

        if opts.only then
          if not item_name or (item_name and file.selected) then
            table.insert(files[kind], file)
          end
        else
          table.insert(files[kind], file)
        end
      end
    end

    return files
  end

  local files = update_files()

  local view = CDiffView {
    git_root = git.repo.worktree_root,
    left = left,
    right = right,
    files = files,
    update_files = update_files,
    get_file_data = function(kind, path, side)
      local args = { path }
      if kind == "staged" then
        if side == "left" then
          table.insert(args, "HEAD")
        end

        return git.cli.show.file(unpack(args)).call({ await = true, trim = false }).stdout
      elseif kind == "working" then
        local fdata = git.cli.show.file(path).call({ await = true, trim = false }).stdout
        return side == "left" and fdata
      end
    end,
  }

  view:on_files_staged(a.void(function(_)
    Watcher.instance():dispatch_refresh()
    view:update_files()
  end))

  dv_lib.add_view(view)

  return view
end

---@param section_name string
---@param item_name    string|string[]|nil
---@param opts         table|nil
function M.open(section_name, item_name, opts)
  opts = opts or {}

  -- Hack way to do an on-close callback
  if opts.on_close then
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
      buffer = opts.on_close.handle,
      once = true,
      callback = opts.on_close.fn,
    })
  end

  local view
  -- selene: allow(if_same_then_else)
  if
    (section_name == "recent" or section_name == "log" or (section_name and section_name:match("unmerged$")))
    and item_name
  then
    local range
    if type(item_name) == "table" then
      range = string.format("%s..%s", item_name[1], item_name[#item_name])
    else
      range = string.format("%s^!", item_name:match("[a-f0-9]+"))
    end

    view = dv_lib.diffview_open(dv_utils.tbl_pack(range))
  elseif section_name == "range" and item_name then
    view = dv_lib.diffview_open(dv_utils.tbl_pack(item_name))
  elseif (section_name == "stashes" or section_name == "commit") and item_name then
    view = dv_lib.diffview_open(dv_utils.tbl_pack(item_name .. "^!"))
  elseif section_name == "conflict" and item_name then
    view = dv_lib.diffview_open(dv_utils.tbl_pack("--selected-file=" .. item_name))
  elseif (section_name == "conflict" or section_name == "worktree") and not item_name then
    view = dv_lib.diffview_open()
  elseif section_name ~= nil then
    -- for staged, unstaged, merge
    view = get_local_diff_view(section_name, item_name, opts)
  elseif section_name == nil and item_name ~= nil then
    view = dv_lib.diffview_open(dv_utils.tbl_pack(item_name .. "^!"))
  else
    view = dv_lib.diffview_open()
  end

  if view then
    view:open()
  end
end

return M
