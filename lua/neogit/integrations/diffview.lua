local M = {}

local Rev = require("diffview.vcs.adapters.git.rev").GitRev
local RevType = require("diffview.vcs.rev").RevType
local CDiffView = require("diffview.api.views.diff.diff_view").CDiffView
local dv_lib = require("diffview.lib")
local dv_utils = require("diffview.utils")

local neogit = require("neogit")
local repo = require("neogit.lib.git.repository")
local status = require("neogit.status")
local a = require("plenary.async")

local function get_local_diff_view(section_name, item_name, opts)
  local left = Rev(RevType.STAGE)
  local right = Rev(RevType.LOCAL)

  if section_name == "unstaged" then
    section_name = "working"
  end

  local function update_files()
    local files = {}

    local sections = {
      conflicting = {
        items = vim.tbl_filter(function(o)
          return o.mode and o.mode:sub(2, 2) == "U"
        end, repo.untracked.items),
      },
      working = repo.unstaged,
      staged = repo.staged,
    }

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
          if (item_name and file.selected) or (not item_name and section_name == kind) then
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
    git_root = repo.git_root,
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

        return neogit.cli.show.file(unpack(args)).call_sync().stdout
      elseif kind == "working" then
        local fdata = neogit.cli.show.file(path).call_sync().stdout
        return side == "left" and fdata
      end
    end,
  }

  view:on_files_staged(a.void(function(_)
    status.refresh({ update_diffs = true }, "on_files_staged")
    view:update_files()
  end))

  dv_lib.add_view(view)

  return view
end

function M.open(section_name, item_name, opts)
  local view

  if section_name == "recent" or section_name == "unmerged" or section_name == "log" then
    local range
    if type(item_name) == "table" then
      range = string.format("%s..%s", item_name[1], item_name[#item_name])
    else
      range = string.format("%s^!", item_name:match("[a-f0-9]+"))
    end

    view = dv_lib.diffview_open(dv_utils.tbl_pack(range))
  elseif (section_name == "stashes" or section_name == "commit") and item_name then
    view = dv_lib.diffview_open(dv_utils.tbl_pack(item_name .. "^!"))
  else
    view = get_local_diff_view(section_name, item_name, opts)
  end

  if view then
    view:open()
  end
end

return M
