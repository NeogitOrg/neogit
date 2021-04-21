local M = {}

M.values = {
  diff_display_kind = "tab",
  disable_context_highlighting = false,
  disable_signs = false,
  on_init = function() end,
  signs = {
    hunk = { "", "" },
    item = { ">", "v" },
    section = { ">", "v" }
  },
  mappings = {
    status = {
      ["q"] = "Close",
      ["1"] = "Depth1",
      ["2"] = "Depth2",
      ["3"] = "Depth3",
      ["4"] = "Depth4",
      ["<tab>"] = "Toggle",
      ["x"] = "Discard",
      ["D"] = "OpenSplitDiff",
      ["s"] = "Stage",
      ["S"] = "StageUnstaged",
      ["<c-s>"] = "StageAll",
      ["u"] = "Unstage",
      ["U"] = "UnstageStaged",
      ["$"] = "CommandHistory",
      ["<c-r>"] = "RefreshBuffer",
      ["<enter>"] = "GoToFile",
      ["<c-v>"] = "VSplitOpen",
      ["<c-x>"] = "SplitOpen",
      ["<c-t>"] = "TabOpen",
      ["?"] = "HelpPopup",
      ["p"] = "PullPopup",
      ["P"] = "PushPopup",
      ["c"] = "CommitPopup",
      ["L"] = "LogPopup",
      ["Z"] = "StashPopup",
      ["b"] = "BranchPopup",
    },
    diff_view = {
      ["q"] = "Close",
      ["<c-s>"] = "Save",
      ["]f"] = "NextFile",
      ["[f"] = "PrevFile",
    }
  }
}

return M
