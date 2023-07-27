local M = {}

function M.get_reversed_status_maps()
  return vim.tbl_add_reverse_lookup(vim.tbl_deep_extend("force", M.values.mappings.status, {}))
end

M.values = {
  disable_hint = false,
  disable_context_highlighting = false,
  disable_signs = false,
  disable_commit_confirmation = false,
  disable_builtin_notifications = false,
  telescope_sorter = function()
    return nil
  end,
  disable_insert_on_commit = true,
  use_per_project_settings = true,
  remember_settings = true,
  use_magit_keybindings = false,
  auto_refresh = true,
  sort_branches = "-committerdate",
  kind = "tab",
  -- The time after which an output console is shown for slow running commands
  console_timeout = 2000,
  -- Automatically show console if a command takes more than console_timeout milliseconds
  auto_show_console = true,
  status = {
    recent_commit_count = 10,
  },
  commit_editor = {
    kind = "split",
  },
  commit_select_view = {
    kind = "tab",
  },
  commit_view = {
    kind = "vsplit",
  },
  log_view = {
    kind = "tab",
  },
  rebase_editor = {
    kind = "split",
  },
  reflog_view = {
    kind = "tab",
  },
  merge_editor = {
    kind = "split",
  },
  preview_buffer = {
    kind = "split",
  },
  popup = {
    kind = "split",
  },
  signs = {
    hunk = { "", "" },
    item = { ">", "v" },
    section = { ">", "v" },
  },
  integrations = {
    telescope = nil,
    diffview = nil,
  },
  sections = {
    untracked = {
      folded = false,
    },
    unstaged = {
      folded = false,
    },
    staged = {
      folded = false,
    },
    stashes = {
      folded = true,
    },
    unpulled_upstream = {
      folded = true,
    },
    unmerged_upstream = {
      folded = false,
    },
    unpulled_pushRemote = {
      folded = true,
    },
    unmerged_pushRemote = {
      folded = false,
    },
    recent = {
      folded = true,
    },
    rebase = {
      folded = true,
    },
  },
  ignored_settings = {
    "NeogitPushPopup--force-with-lease",
    "NeogitPushPopup--force",
    "NeogitPullPopup--rebase",
    "NeogitCommitPopup--allow-empty",
    "NeogitRevertPopup--no-edit", -- TODO: Fix incompatible switches with default enables
  },
  mappings = {
    finder = {
      ["<cr>"] = "Select",
      ["<c-c>"] = "Close",
      ["<esc>"] = "Close",
      ["<c-n>"] = "Next",
      ["<c-p>"] = "Previous",
      ["<down>"] = "Next",
      ["<up>"] = "Previous",
      ["<tab>"] = "MultiselectToggleNext",
      ["<s-tab>"] = "MultiselectTogglePrevious",
      ["<c-j>"] = "NOP",
    },
    status = {
      ["q"] = "Close",
      ["I"] = "InitRepo",
      ["1"] = "Depth1",
      ["2"] = "Depth2",
      ["3"] = "Depth3",
      ["4"] = "Depth4",
      ["<tab>"] = "Toggle",
      ["x"] = "Discard",
      ["s"] = "Stage",
      ["S"] = "StageUnstaged",
      ["<c-s>"] = "StageAll",
      ["u"] = "Unstage",
      ["U"] = "UnstageStaged",
      ["d"] = "DiffAtFile",
      ["$"] = "CommandHistory",
      ["#"] = "Console",
      ["<c-r>"] = "RefreshBuffer",
      ["<enter>"] = "GoToFile",
      ["<c-v>"] = "VSplitOpen",
      ["<c-x>"] = "SplitOpen",
      ["<c-t>"] = "TabOpen",
      ["?"] = "HelpPopup",
      ["D"] = "DiffPopup",
      ["p"] = "PullPopup",
      ["r"] = "RebasePopup",
      ["m"] = "MergePopup",
      ["P"] = "PushPopup",
      ["c"] = "CommitPopup",
      ["L"] = "LogPopup",
      ["v"] = "RevertPopup",
      ["Z"] = "StashPopup",
      ["A"] = "CherryPickPopup",
      ["b"] = "BranchPopup",
      ["f"] = "FetchPopup",
      ["X"] = "ResetPopup",
      ["M"] = "RemotePopup",
      ["{"] = "GoToPreviousHunkHeader",
      ["}"] = "GoToNextHunkHeader",
    },
  },
}

---@param name string
---@return boolean
function M.check_integration(name)
  local logger = require("neogit.logger")
  local enabled = M.values.integrations[name]

  if enabled == nil or enabled == "auto" then
    local success, _ = pcall(require, name)
    logger.fmt_info("[CONFIG] Found auto integration '%s = %s'", name, success)
    return success
  end

  logger.fmt_info("[CONFIG] Found explicit integration '%s' = %s", name, enabled)
  return enabled
end

return M
