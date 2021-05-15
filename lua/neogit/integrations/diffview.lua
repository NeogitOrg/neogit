local M = {}

local dv = require 'diffview'
local dv_config = require 'diffview.config'
local neogit = require 'neogit'

local old_config

__neogit_diffview_mappings = {
  close = function()
    vim.cmd [[tabclose]]
    neogit.dispatch_refresh()
    dv.setup(old_config)
  end
}

local function cb(name)
  return string.format(":lua __neogit_diffview_mappings['%s']()<CR>", name)
end

function M.open()
  old_config = dv_config.get_config()

  local keybindings = vim.tbl_deep_extend("force", dv_config.defaults.key_bindings, {
    view = {
      ["q"] = cb("close"),
      ["<esc>"] = cb("close")
    },
    file_panel = {
      ["q"] = cb("close"),
      ["<esc>"] = cb("close")
    }
  })

  dv.setup {
    key_bindings = keybindings
  }

  return dv.open()
end

function M.open_at_file(file_name)
  local view = M.open()

  for i=1,#view.files do
    local file = view.files[i]
    if file.path == file_name then
      view:set_file(file, true)
      break
    end
  end

  return view
end

return M
