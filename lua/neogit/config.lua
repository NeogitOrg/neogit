local M = {}

function M.get_copy()
  return vim.tbl_deep_extend("force", M.values, {})
end

---@alias WindowKind
---|"split" Open in a split
---| "vsplit" Open in a vertical split
---| "float" Open in a floating window
---| "tab" Open in a new tab

---@class NeogitConfigPopup Popup window options
---@field kind WindowKind The type of window that should be opened

---@alias NeogitConfigSignsIcon { [1]: string, [2]: string }

---@class NeogitConfigSigns
---@field hunk NeogitConfigSignsIcon The icons to use for open and closed hunks
---@field item NeogitConfigSignsIcon The icons to use for open and closed items
---@field section NeogitConfigSignsIcon The icons to use for open and closed sections

---@class NeogitConfigSection A section to show in the Neogit Status buffer, e.g. Staged/Unstaged/Untracked
---@field folded boolean Whether or not this section should be shown by default

---@class NeogitConfigSections
---@field untracked NeogitConfigSection
---@field unstaged NeogitConfigSection
---@field staged NeogitConfigSection
---@field stashes NeogitConfigSection
---@field unpulled NeogitConfigSection
---@field unmerged NeogitConfigSection
---@field recent NeogitConfigSection
---@field rebase NeogitConfigSection

---@class NeogitConfigMappings Consult the config file or documentation for values
---@field finder { [string]: string[] } A dictionary that uses finder commands to set multiple keybinds
---@field status { [string]: string } A dictionary that uses status commands to set a single keybind

---@class NeogitConfig Neogit configuration settings
---@field disable_hint boolean Remove the top hint in the Status buffer
---@field disable_context_highlighting boolean Disable context highlights based on cursor position
---@field disable_commit_confirmation boolean Disable commit confirmations
---@field use_per_project_settings boolean Scope persisted settings on a per-project basis
---@field auto_refresh boolean Automatically refresh to detect git modifications without manual intervention
---@field sort_branches string Value used for `--sort` for the `git branch` command
---@field disable_builtin_notifications boolean Disable Neogit's own notifications and use vim.notify
---@field use_telescope boolean Use telescope instead of vim.ui.select
---@field telescope_sorter function The sorter telescope will use
---@field use_magit_keybindings boolean  Use magit keybinds from emacs
---@field kind WindowKind The default type of window neogit should open in
---@field console_timeout integer Time in milliseconds after a console is created for long running commands
---@field auto_show_console boolean Automatically show the console if a command takes longer than console_timout
---@field status { recent_commit_count: integer } Status buffer options
---@field commit_editor NeogitConfigPopup Commit editor options
---@field commit_select_view NeogitConfigPopup Commit select view options
---@field commit_view NeogitConfigPopup Commit view options
---@field log_view NeogitConfigPopup Log view options
---@field rebase_editor NeogitConfigPopup Rebase editor options
---@field reflog_view NeogitConfigPopup Reflog view options
---@field merge_editor NeogitConfigPopup Merge editor options
---@field preview_buffer NeogitConfigPopup Preview options
---@field popup NeogitConfigPopup Set the default way of opening popups
---@field signs NeogitConfigSigns Signs used for toggled regions
---@field integrations { diffview: boolean } Which integrations to enable
---@field sections NeogitConfigSections
---@field ignored_settings string[] Settings to never persist, format: "Filetype--cli-value", i.e. "NeogitCommitPopup--author"
---@field mappings NeogitConfigMappings
M.values = {
  disable_hint = false,
  disable_context_highlighting = false,
  disable_signs = false,
  disable_commit_confirmation = false,
  disable_builtin_notifications = false,
  use_telescope = false,
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
  integrations = setmetatable({}, {
    __index = function(_, key)
      local ok, value = pcall(require, key)
      return ok and value or false
    end,
  }),
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
    unpulled = {
      folded = true,
    },
    unmerged = {
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
    "NeogitCommitPopup--allow-empty",
    "NeogitRevertPopup--no-edit", -- TODO: Fix incompatible switches with default enables
  },
  mappings = {
    finder = {
      ["Select"] = { "<cr>" },
      ["Close"] = { "<c-c>", "<esc>" },
      ["Next"] = { "<c-n>", "<down>" },
      ["Previous"] = { "<c-p>", "<up>" },
      ["MultiselectToggleNext"] = { "<tab>" },
      ["MultiselectTogglePrevious"] = { "<s-tab>" },
      ["NOP"] = { "<c-j>" },
    },
    status = {
      ["Close"] = "q",
      ["InitRepo"] = "I",
      ["Depth1"] = "1",
      ["Depth2"] = "2",
      ["Depth3"] = "3",
      ["Depth4"] = "4",
      ["Toggle"] = "<tab>",
      ["Discard"] = "x",
      ["Stage"] = "s",
      ["StageUnstaged"] = "S",
      ["StageAll"] = "<c-s>",
      ["Unstage"] = "u",
      ["UnstageStaged"] = "U",
      ["DiffAtFile"] = "d",
      ["CommandHistory"] = "$",
      ["Console"] = "#",
      ["RefreshBuffer"] = "<c-r>",
      ["GoToFile"] = "<enter>",
      ["VSplitOpen"] = "<c-v>",
      ["SplitOpen"] = "<c-x>",
      ["TabOpen"] = "<c-t>",
      ["HelpPopup"] = "?",
      ["DiffPopup"] = "D",
      ["PullPopup"] = "p",
      ["RebasePopup"] = "r",
      ["MergePopup"] = "m",
      ["PushPopup"] = "P",
      ["CommitPopup"] = "c",
      ["LogPopup"] = "L",
      ["RevertPopup"] = "_",
      ["StashPopup"] = "Z",
      ["CherryPickPopup"] = "A",
      ["BranchPopup"] = "b",
      ["FetchPopup"] = "f",
      ["ResetPopup"] = "X",
      ["RemotePopup"] = "M",
      ["GoToPreviousHunkHeader"] = "{",
      ["GoToNextHunkHeader"] = "}",
    },
  },
}

function M.ensure_integration(name)
  if not M.values.integrations[name] then
    vim.api.nvim_err_writeln(string.format("Neogit: `%s` integration is not enabled", name))
    return false
  end

  return true
end

return M
