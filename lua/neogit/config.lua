local M = {}

M.values = {
  disable_hint = false,
  disable_context_highlighting = false,
  disable_signs = false,
  disable_commit_confirmation = false,
  disable_builtin_notifications = false,
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
  commit_popup = {
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
    diffview = false,
    telescope = false,
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
  ignored_settings = {},
  mappings = {
    status = {
      ["q"] = "Close",
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
      ["P"] = "PushPopup",
      ["c"] = "CommitPopup",
      ["L"] = "LogPopup",
      ["Z"] = "StashPopup",
      ["A"] = "CherryPickPopup",
      ["b"] = "BranchPopup",
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
