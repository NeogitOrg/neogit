local M = {}

local dv = require 'diffview'
local dv_config = require 'diffview.config'
local Rev = require'diffview.git.rev'.Rev
local RevType = require'diffview.git.rev'.RevType
local CDiffView = require'diffview.api.views.diff.diff_view'.CDiffView
local dv_lib = require'diffview.lib'
local dv_utils = require("diffview.utils")

local neogit = require 'neogit'
local status = require'neogit.status'
local a = require 'plenary.async'

local old_config

M.diffview_mappings = {
  close = function()
    vim.cmd [[tabclose]]
    neogit.dispatch_refresh()
    dv.setup(old_config)
  end
}

local function cb(name)
  return string.format(":lua require('neogit.integrations.diffview').diffview_mappings['%s']()<CR>", name)
end


local function get_local_diff_view(selected_file_name)
  local left = Rev(RevType.INDEX)
  local right = Rev(RevType.LOCAL)
  local git_root = neogit.cli.git_root_sync()

  local function update_files()
    local files = {}
    local repo = neogit.get_repo()
    local sections = {
      working = repo.unstaged,
      staged = repo.staged
    }
    for kind, section in pairs(sections) do
      files[kind] = {}
      for _, item in ipairs(section.items) do
        local file = {
          path = item.name,
          status = item.mode,
          stats = (item.diff and item.diff.stats) and {
            additions = item.diff.stats.additions or 0,
            deletions = item.diff.stats.deletions or 0
          } or nil,
          left_null = vim.tbl_contains({ "A", "?" }, item.mode),
          right_null = false,
          selected = item.name == selected_file_name
        }

        table.insert(files[kind], file)
      end
    end
    selected_file_name = nil
    return files
  end

  local files = update_files()

  local view = CDiffView({
    git_root = git_root,
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
        return neogit.cli.show.file(unpack(args)).call_sync()
      elseif kind == "working" then
        return side == "left"
          and neogit.cli.show.file(path).call_sync()
          or nil
      end
    end
  })

  view:on_files_staged(a.void(function (_)
    status.refresh({ status = true, diffs = true })
    view:update_files()
  end))

  dv_lib.add_view(view)

  return view
end

function M.open(section_name, item_name)
  old_config = dv_config.get_config()

  local config = vim.tbl_deep_extend("force", old_config, {
    key_bindings = {
      view = {
        ["q"] = cb("close"),
        ["<esc>"] = cb("close")
      },
      file_panel = {
        ["q"] = cb("close"),
        ["<esc>"] = cb("close")
      }
    }
  })

  dv.setup(config)

  local view

  if section_name == "recent" or section_name == "unmerged" then
    local commit_id = item_name:match("[a-f0-9]+")
    view = dv_lib.diffview_open(dv_utils.tbl_pack(commit_id.."^.."..commit_id))
  elseif section_name == "stashes" then
    local stash_id = item_name:match("stash@{%d+}")
    view = dv_lib.diffview_open(dv_utils.tbl_pack(stash_id.."^.."..stash_id))
  else
    view = get_local_diff_view(item_name)
  end

  if view then
    view:open()
  end

  return view
end

return M
