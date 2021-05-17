local M = {}

local dv = require 'diffview'
local dv_config = require 'diffview.config'
local Rev = require'diffview.rev'.Rev
local RevType = require'diffview.rev'.RevType
local CView = require'diffview.api.c-view'.CView
local dv_lib = require'diffview.lib'

local neogit = require 'neogit'
local util = require 'neogit.lib.util'
local a = require 'plenary.async_lib'
local async, await, scheduler = a.async, a.await, a.scheduler

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

function M.open(selected_file_name)
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

  local left = Rev:new(RevType.COMMIT, neogit.repo.head.oid)
  local right = Rev:new(RevType.LOCAL, nil, true)
  local git_root = neogit.cli.git_root_sync()

  local function update_files()
    local files = {}
    for _, section in ipairs({neogit.repo.unstaged}) do
      for _, item in ipairs(section.files) do
        local file = {
          path = item.name,
          status = item.mode,
          stats = {
            additions = item.diff.stats.additions or 0,
            deletions = item.diff.stats.deletions or 0
          },
          left_null = item.mode == "A",
          right_null = false,
          selected = path == selected_file_name
        }

        table.insert(files, file)
      end
    end
    selected_file_name = nil
    return files
  end

  local files = update_files()

  local view = CView:new {
    git_root = git_root,
    left = left,
    right = right,
    files = files,
    update_files = update_files,
    get_file_data = function(path, side)
      return side == "left" 
        and neogit.cli.show.file(path).call_sync() 
        or nil
    end
  }

  dv_lib.add_view(view)

  view:open()

  return view
end

return M
