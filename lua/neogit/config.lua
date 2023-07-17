local M = {}

function M.get_copy()
  return vim.tbl_deep_extend("force", M.values, {})
end

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
