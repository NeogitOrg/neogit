local M = {}

M.values = {
  disable_context_highlighting = false,
  disable_signs = false,
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
      ["s"] = "Stage",
      ["S"] = "StageUnstaged",
      ["<c-s>"] = "StageAll",
      ["u"] = "Unstage",
      ["U"] = "UnstageStaged",
      ["$"] = "CommandHistory",
      ["<c-r>"] = "RefreshBuffer",
      ["<enter>"] = "GoToFile",
      ["?"] = "HelpPopup",
      ["p"] = "PullPopup",
      ["P"] = "PushPopup",
      ["c"] = "CommitPopup",
      ["L"] = "LogPopup",
      ["Z"] = "StashPopup",
      ["b"] = "BranchPopup",
    }
  }
}

return M
