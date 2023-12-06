local M = {}

local dv = require("diffview")
local dv_config = require("diffview.config")
local Rev = require("diffview.vcs.adapters.git.rev").GitRev
local RevType = require("diffview.vcs.rev").RevType
local CDiffView = require("diffview.api.views.diff.diff_view").CDiffView
local dv_lib = require("diffview.lib")
local dv_utils = require("diffview.utils")

local neogit = require("neogit")
local repo = require("neogit.lib.git.repository")
local status = require("neogit.status")
local a = require("plenary.async")

local old_config

local function remove_trailing_blankline(lines)
  if lines[#lines] ~= "" then
    error("Git show did not end with a blankline")
  end

  lines[#lines] = nil
  return lines
end

M.diffview_mappings = {
  close = function()
    vim.cmd("tabclose")
    neogit.dispatch_refresh()
    dv.setup(old_config)
  end,
}

local function cb(name)
  return string.format(":lua require('neogit.integrations.diffview').diffview_mappings['%s']()<CR>", name)
end

local function get_local_diff_view(selected_file_name)
  local left = Rev(RevType.STAGE)
  local right = Rev(RevType.LOCAL)

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
      for _, item in ipairs(section.items) do
        local file = {
          path = item.name,
          status = item.mode and item.mode:sub(1, 1),
          stats = (item.diff and item.diff.stats) and {
            additions = item.diff.stats.additions or 0,
            deletions = item.diff.stats.deletions or 0,
          } or nil,
          left_null = vim.tbl_contains({ "A", "?" }, item.mode),
          right_null = false,
          selected = item.name == selected_file_name,
        }

        table.insert(files[kind], file)
      end
    end
    selected_file_name = nil
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
        return remove_trailing_blankline(neogit.cli.show.file(unpack(args)).call_sync().stdout)
      elseif kind == "working" then
        local fdata = remove_trailing_blankline(neogit.cli.show.file(path).call_sync().stdout)
        return side == "left" and fdata
      end
    end,
  }

  view:on_files_staged(a.void(function(_)
    status.refresh({ status = true, diffs = true }, "on_files_staged")
    view:update_files()
  end))

  dv_lib.add_view(view)

  return view
end

function M.open(section_name, item_name)
  old_config = vim.deepcopy(dv_config.get_config())

  local config = dv_config.get_config()

  local keymaps = {
    view = {
      ["q"] = cb("close"),
      ["<esc>"] = cb("close"),
    },
    file_panel = {
      ["q"] = cb("close"),
      ["<esc>"] = cb("close"),
    },
  }

  for key, keymap in pairs(keymaps) do
    config.keymaps[key] = dv_config.extend_keymaps(keymap, config.keymaps[key] or {})
  end

  dv.setup(config)

  local view

  if section_name == "recent" or section_name == "unmerged" or section_name == "log" then
    local range
    if type(item_name) == "table" then
      range = string.format("%s..%s", item_name[1], item_name[#item_name])
    else
      range = string.format("%s^!", item_name:match("[a-f0-9]+"))
    end

    view = dv_lib.diffview_open(dv_utils.tbl_pack(range))
  elseif section_name == "stashes" then
    local stash_id = item_name:match("stash@{%d+}")
    view = dv_lib.diffview_open(dv_utils.tbl_pack(stash_id .. "^!"))
  else
    view = get_local_diff_view(item_name)
  end

  if view then
    view:open()
  end
  return view
end

return M
