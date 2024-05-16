local M = {}

local dv = require("diffview")
local dv_config = require("diffview.config")
local Rev = require("diffview.vcs.adapters.git.rev").GitRev
local RevType = require("diffview.vcs.rev").RevType
local CDiffView = require("diffview.api.views.diff.diff_view").CDiffView
local dv_lib = require("diffview.lib")
local dv_utils = require("diffview.utils")

local neogit = require("neogit")
local git = require("neogit.lib.git")
local status = require("neogit.buffers.status")
local a = require("plenary.async")

local old_config

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
        end, git.repo.state.untracked.items),
      },
      working = git.repo.state.unstaged,
      staged = git.repo.state.staged,
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
    git_root = git.repo.git_root,
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

        return git.cli.show.file(unpack(args)).call_sync({ trim = false }).stdout
      elseif kind == "working" then
        local fdata = git.cli.show.file(path).call_sync({ trim = false }).stdout
        return side == "left" and fdata
      end
    end,
  }

  view:on_files_staged(a.void(function(_)
    if status.is_open() then
      status.instance():dispatch_refresh({ update_diffs = true }, "on_files_staged")
    end

    view:update_files()
  end))

  dv_lib.add_view(view)

  return view
end

function M.open(section_name, item_name, opts)
  opts = opts or {}
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
    elseif item_name ~= nil then
      range = string.format("%s^!", item_name:match("[a-f0-9]+"))
    else
      return
    end

    view = dv_lib.diffview_open(dv_utils.tbl_pack(range))
  elseif section_name == "range" then
    local range = item_name
    view = dv_lib.diffview_open(dv_utils.tbl_pack(range))
  elseif section_name == "stashes" then
    -- TODO: Fix when no item name
    local stash_id = item_name:match("stash@{%d+}")
    view = dv_lib.diffview_open(dv_utils.tbl_pack(stash_id .. "^!"))
  elseif section_name == "commit" then
    view = dv_lib.diffview_open(dv_utils.tbl_pack(item_name .. "^!"))
  elseif section_name ~= nil then
    view = get_local_diff_view(section_name, item_name, opts)
  else
    view = dv_lib.diffview_open(dv_utils.tbl_pack(item_name .. "^!"))
  end

  if view then
    view:open()
  end
end

return M
