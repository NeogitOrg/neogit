local util = require("neogit.lib.util")
local M = {}

local mappings = {}

---Returns a map of commands, mapped to the list of keys which trigger them.
---@return table<string, string[]>
local function get_reversed_maps(set)
  if not mappings[set] then
    local result = {}
    for k, v in pairs(M.values.mappings[set]) do
      -- If `v == false` the mapping is disabled
      if v then
        local current = result[v]
        if current then
          table.insert(current, k)
        else
          result[v] = { k }
        end
      end
    end

    setmetatable(result, {
      __index = function()
        return "<nop>"
      end,
    })

    mappings[set] = result
  end

  return mappings[set]
end

---@return table<string, string[]>
function M.get_reversed_status_maps()
  return get_reversed_maps("status")
end

---@return table<string, string[]>
function M.get_reversed_popup_maps()
  return get_reversed_maps("popup")
end

---@return table<string, string[]>
function M.get_reversed_rebase_editor_maps()
  return get_reversed_maps("rebase_editor")
end

---@return table<string, string[]>
function M.get_reversed_rebase_editor_maps_I()
  return get_reversed_maps("rebase_editor_I")
end

---@return table<string, string[]>
function M.get_reversed_commit_editor_maps()
  return get_reversed_maps("commit_editor")
end

---@return table<string, string[]>
function M.get_reversed_commit_editor_maps_I()
  return get_reversed_maps("commit_editor_I")
end
---
---@return table<string, string[]>
function M.get_reversed_refs_view_maps()
  return get_reversed_maps("refs_view")
end

---@param set string
---@return table<string, string[]>
function M.get_user_mappings(set)
  local mappings = {}

  for k, v in pairs(get_reversed_maps(set)) do
    if type(k) == "function" then
      for _, trigger in ipairs(v) do
        mappings[trigger] = k
      end
    end
  end

  return mappings
end

---@alias WindowKind
---| "replace" Like :enew
---| "tab" Open in a new tab
---| "split" Open in a split
---| "split_above" Like :top split
---| "split_above_all" Like :top split
---| "split_below" Like :below split
---| "split_below_all" Like :below split
---| "vsplit" Open in a vertical split
---| "floating" Open in a floating window
---| "auto" vsplit if window would have 80 cols, otherwise split

---@class NeogitCommitBufferConfig Commit buffer options
---@field kind WindowKind The type of window that should be opened
---@field verify_commit boolean Show commit signature information in the buffer

---@class NeogitConfigPopup Popup window options
---@field kind WindowKind The type of window that should be opened

---@class NeogitConfigFloating
---@field relative? string
---@field width? number
---@field height? number
---@field col? number
---@field row? number
---@field style? string
---@field border? string

---@alias StagedDiffSplitKind
---| "split" Open in a split
---| "vsplit" Open in a vertical split
---| "split_above" Like :top split
---| "auto" "vsplit" if window would have 80 cols, otherwise "split"

---@class NeogitCommitEditorConfigPopup Popup window options
---@field kind WindowKind The type of window that should be opened
---@field show_staged_diff? boolean Display staged changes in a buffer when committing
---@field staged_diff_split_kind? StagedDiffSplitKind Whether to show staged changes in a vertical or horizontal split
---@field spell_check? boolean Enable/Disable spell checking

---@alias NeogitConfigSignsIcon { [1]: string, [2]: string }

---@class NeogitConfigSigns
---@field hunk NeogitConfigSignsIcon The icons to use for open and closed hunks
---@field item NeogitConfigSignsIcon The icons to use for open and closed items
---@field section NeogitConfigSignsIcon The icons to use for open and closed sections

---@class NeogitConfigSection A section to show in the Neogit Status buffer, e.g. Staged/Unstaged/Untracked
---@field folded boolean Whether or not this section should be open or closed by default
---@field hidden boolean Whether or not this section should be shown

---@class NeogitConfigSections
---@field untracked NeogitConfigSection|nil
---@field unstaged NeogitConfigSection|nil
---@field staged NeogitConfigSection|nil
---@field stashes NeogitConfigSection|nil
---@field unpulled_upstream NeogitConfigSection|nil
---@field unmerged_upstream NeogitConfigSection|nil
---@field unpulled_pushRemote NeogitConfigSection|nil
---@field unmerged_pushRemote NeogitConfigSection|nil
---@field recent NeogitConfigSection|nil
---@field rebase NeogitConfigSection|nil
---@field sequencer NeogitConfigSection|nil
---@field bisect NeogitConfigSection|nil

---@class HighlightOptions
---@field italic?     boolean
---@field bold?       boolean
---@field underline?  boolean
---@field bg0?        string  Darkest background color
---@field bg1?        string  Second darkest background color
---@field bg2?        string  Second lightest background color
---@field bg3?        string  Lightest background color
---@field grey?       string  middle grey shade for foreground
---@field white?      string  Foreground white (main text)
---@field red?        string  Foreground red
---@field bg_red?     string  Background red
---@field line_red?   string  Cursor line highlight for red regions, like deleted hunks
---@field orange?     string  Foreground orange
---@field bg_orange?  string  background orange
---@field yellow?     string  Foreground yellow
---@field bg_yellow?  string  background yellow
---@field green?      string  Foreground green
---@field bg_green?   string  Background green
---@field line_green? string  Cursor line highlight for green regions, like added hunks
---@field cyan?       string  Foreground cyan
---@field bg_cyan?    string  Background cyan
---@field blue?       string  Foreground blue
---@field bg_blue?    string  Background blue
---@field purple?     string  Foreground purple
---@field bg_purple?  string  Background purple
---@field md_purple?  string  Background _medium_ purple. Lighter than bg_purple. Used for hunk headers.

---@class NeogitFilewatcherConfig
---@field enabled boolean
---@field filewatcher NeogitFilewatcherConfig|nil

---@alias NeogitConfigMappingsFinder
---| "Select"
---| "Close"
---| "Next"
---| "Previous"
---| "MultiselectToggleNext"
---| "MultiselectTogglePrevious"
---| "InsertCompletion"
---| "NOP"
---| false

---@alias NeogitConfigMappingsStatus
---| "Close"
---| "MoveDown"
---| "MoveUp"
---| "OpenTree"
---| "Command"
---| "Depth1"
---| "Depth2"
---| "Depth3"
---| "Depth4"
---| "Toggle"
---| "Discard"
---| "Stage"
---| "StageUnstaged"
---| "StageAll"
---| "Unstage"
---| "UnstageStaged"
---| "Untrack"
---| "RefreshBuffer"
---| "GoToFile"
---| "VSplitOpen"
---| "SplitOpen"
---| "TabOpen"
---| "GoToPreviousHunkHeader"
---| "GoToNextHunkHeader"
---| "CommandHistory"
---| "ShowRefs"
---| "InitRepo"
---| "YankSelected"
---| "OpenOrScrollUp"
---| "OpenOrScrollDown"
---| "PeekUp"
---| "PeekDown"
---| "NextSection"
---| "PreviousSection"
---| false
---| fun()

---@alias NeogitConfigMappingsPopup
---| "HelpPopup"
---| "DiffPopup"
---| "PullPopup"
---| "RebasePopup"
---| "MergePopup"
---| "PushPopup"
---| "CommitPopup"
---| "LogPopup"
---| "RevertPopup"
---| "StashPopup"
---| "IgnorePopup"
---| "CherryPickPopup"
---| "BisectPopup"
---| "BranchPopup"
---| "FetchPopup"
---| "ResetPopup"
---| "RemotePopup"
---| "TagPopup"
---| "WorktreePopup"
---| false

---@alias NeogitConfigMappingsRebaseEditor
---| "Pick"
---| "Reword"
---| "Edit"
---| "Squash"
---| "Fixup"
---| "Execute"
---| "Drop"
---| "Break"
---| "MoveUp"
---| "MoveDown"
---| "Close"
---| "OpenCommit"
---| "Submit"
---| "Abort"
---| "OpenOrScrollUp"
---| "OpenOrScrollDown"
---| false
---| fun()

---@alias NeogitConfigMappingsCommitEditor
---| "Close"
---| "Submit"
---| "Abort"
---| "PrevMessage"
---| "ResetMessage"
---| "NextMessage"
---| false
---| fun()

---@alias NeogitConfigMappingsCommitEditor_I
---| "Submit"
---| "Abort"
---| false
---| fun()

---@alias NeogitConfigMappingsRebaseEditor_I
---| "Submit"
---| "Abort"
---| false
---| fun()
---
---@alias NeogitConfigMappingsRefsView
---| "DeleteBranch"
---| false
---| fun()

---@alias NeogitGraphStyle
---| "ascii"
---| "unicode"
---| "kitty"

---@class NeogitConfigStatusOptions
---@field recent_commit_count? integer The number of recent commits to display
---@field mode_padding? integer The amount of padding to add to the right of the mode column
---@field HEAD_padding? integer The amount of padding to add to the right of the HEAD label
---@field HEAD_folded? boolean Whether or not this section should be open or closed by default
---@field mode_text? { [string]: string } The text to display for each mode
---@field show_head_commit_hash? boolean Show the commit hash for HEADs in the status buffer

---@class NeogitConfigMappings Consult the config file or documentation for values
---@field finder? { [string]: NeogitConfigMappingsFinder } A dictionary that uses finder commands to set multiple keybinds
---@field status? { [string]: NeogitConfigMappingsStatus } A dictionary that uses status commands to set a single keybind
---@field popup? { [string]: NeogitConfigMappingsPopup } A dictionary that uses popup commands to set a single keybind
---@field rebase_editor? { [string]: NeogitConfigMappingsRebaseEditor } A dictionary that uses Rebase editor commands to set a single keybind
---@field rebase_editor_I? { [string]: NeogitConfigMappingsRebaseEditor_I } A dictionary that uses Rebase editor commands to set a single keybind
---@field commit_editor? { [string]: NeogitConfigMappingsCommitEditor } A dictionary that uses Commit editor commands to set a single keybind
---@field commit_editor_I? { [string]: NeogitConfigMappingsCommitEditor_I } A dictionary that uses Commit editor commands to set a single keybind
---@field refs_view? { [string]: NeogitConfigMappingsRefsView } A dictionary that uses Refs view editor commands to set a single keybind

---@class NeogitConfig Neogit configuration settings
---@field filewatcher? NeogitFilewatcherConfig Values for filewatcher
---@field graph_style? NeogitGraphStyle Style for graph
---@field commit_date_format? string Commit date format
---@field log_date_format? string Log date format
---@field disable_hint? boolean Remove the top hint in the Status buffer
---@field disable_context_highlighting? boolean Disable context highlights based on cursor position
---@field disable_signs? boolean Special signs to draw for sections etc. in Neogit
---@field prompt_force_push? boolean Offer to force push when branches diverge
---@field git_services? table Templartes to use when opening a pull request for a branch
---@field fetch_after_checkout? boolean Perform a fetch if the newly checked out branch has an upstream or pushRemote set
---@field telescope_sorter? function The sorter telescope will use
---@field process_spinner? boolean Hide/Show the process spinner
---@field disable_insert_on_commit? boolean|"auto" Disable automatically entering insert mode in commit dialogues
---@field use_per_project_settings? boolean Scope persisted settings on a per-project basis
---@field remember_settings? boolean Whether neogit should persist flags from popups, e.g. git push flags
---@field sort_branches? string Value used for `--sort` for the `git branch` command
---@field initial_branch_name? string Default for new branch name prompts
---@field kind? WindowKind The default type of window neogit should open in
---@field floating? NeogitConfigFloating The floating window style
---@field disable_line_numbers? boolean Whether to disable line numbers
---@field disable_relative_line_numbers? boolean Whether to disable line numbers
---@field console_timeout? integer Time in milliseconds after a console is created for long running commands
---@field auto_show_console? boolean Automatically show the console if a command takes longer than console_timeout
---@field auto_show_console_on? string Specify "output" (show always; default) or "error" if `auto_show_console` enabled
---@field auto_close_console? boolean Automatically hide the console if the process exits with a 0 status
---@field status? NeogitConfigStatusOptions Status buffer options
---@field commit_editor? NeogitCommitEditorConfigPopup Commit editor options
---@field commit_select_view? NeogitConfigPopup Commit select view options
---@field stash? NeogitConfigPopup Commit select view options
---@field commit_view? NeogitCommitBufferConfig Commit buffer options
---@field log_view? NeogitConfigPopup Log view options
---@field rebase_editor? NeogitConfigPopup Rebase editor options
---@field reflog_view? NeogitConfigPopup Reflog view options
---@field refs_view? NeogitConfigPopup Refs view options
---@field merge_editor? NeogitConfigPopup Merge editor options
---@field description_editor? NeogitConfigPopup Merge editor options
---@field tag_editor? NeogitConfigPopup Tag editor options
---@field preview_buffer? NeogitConfigPopup Preview options
---@field popup? NeogitConfigPopup Set the default way of opening popups
---@field signs? NeogitConfigSigns Signs used for toggled regions
---@field integrations? { diffview: boolean, telescope: boolean, fzf_lua: boolean, mini_pick: boolean } Which integrations to enable
---@field sections? NeogitConfigSections
---@field ignored_settings? string[] Settings to never persist, format: "Filetype--cli-value", i.e. "NeogitCommitPopup--author"
---@field mappings? NeogitConfigMappings
---@field notification_icon? string
---@field use_default_keymaps? boolean
---@field highlight? HighlightOptions
---@field builders? { [string]: fun(builder: PopupBuilder) }

---Returns the default Neogit configuration
---@return NeogitConfig
function M.get_default_values()
  return {
    use_default_keymaps = true,
    disable_hint = false,
    disable_context_highlighting = false,
    disable_signs = false,
    prompt_force_push = true,
    graph_style = "ascii",
    commit_date_format = nil,
    log_date_format = nil,
    process_spinner = false,
    filewatcher = {
      enabled = true,
    },
    telescope_sorter = function()
      return nil
    end,
    git_services = {
      ["github.com"] = "https://github.com/${owner}/${repository}/compare/${branch_name}?expand=1",
      ["bitbucket.org"] = "https://bitbucket.org/${owner}/${repository}/pull-requests/new?source=${branch_name}&t=1",
      ["gitlab.com"] = "https://gitlab.com/${owner}/${repository}/merge_requests/new?merge_request[source_branch]=${branch_name}",
      ["azure.com"] = "https://dev.azure.com/${owner}/_git/${repository}/pullrequestcreate?sourceRef=${branch_name}&targetRef=${target}",
    },
    highlight = {},
    disable_insert_on_commit = "auto",
    use_per_project_settings = true,
    remember_settings = true,
    fetch_after_checkout = false,
    sort_branches = "-committerdate",
    kind = "tab",
    floating = {
      relative = "editor",
      width = 0.8,
      height = 0.7,
      style = "minimal",
      border = "rounded",
    },
    initial_branch_name = "",
    disable_line_numbers = true,
    disable_relative_line_numbers = true,
    -- The time after which an output console is shown for slow running commands
    console_timeout = 2000,
    -- Automatically show console if a command takes more than console_timeout milliseconds
    auto_show_console = true,
    -- If `auto_show_console` is enabled, specify "output" (default) to show
    -- the console always, or "error" to auto-show the console only on error
    auto_show_console_on = "output",
    auto_close_console = true,
    notification_icon = "󰊢",
    status = {
      show_head_commit_hash = true,
      recent_commit_count = 10,
      HEAD_padding = 10,
      HEAD_folded = false,
      mode_padding = 3,
      mode_text = {
        M = "modified",
        N = "new file",
        A = "added",
        D = "deleted",
        C = "copied",
        U = "updated",
        R = "renamed",
        T = "changed",
        DD = "unmerged",
        AU = "unmerged",
        UD = "unmerged",
        UA = "unmerged",
        DU = "unmerged",
        AA = "unmerged",
        UU = "unmerged",
        ["?"] = "",
      },
    },
    commit_editor = {
      kind = "tab",
      show_staged_diff = true,
      staged_diff_split_kind = "split",
      spell_check = true,
    },
    commit_select_view = {
      kind = "tab",
    },
    commit_view = {
      kind = "vsplit",
      verify_commit = vim.fn.executable("gpg") == 1,
    },
    log_view = {
      kind = "tab",
    },
    rebase_editor = {
      kind = "auto",
    },
    reflog_view = {
      kind = "tab",
    },
    merge_editor = {
      kind = "auto",
    },
    description_editor = {
      kind = "auto",
    },
    tag_editor = {
      kind = "auto",
    },
    preview_buffer = {
      kind = "floating_console",
    },
    popup = {
      kind = "split",
    },
    stash = {
      kind = "tab",
    },
    refs_view = {
      kind = "tab",
    },
    signs = {
      hunk = { "", "" },
      item = { ">", "v" },
      section = { ">", "v" },
    },
    integrations = {
      telescope = nil,
      diffview = nil,
      fzf_lua = nil,
      mini_pick = nil,
    },
    sections = {
      sequencer = {
        folded = false,
        hidden = false,
      },
      bisect = {
        folded = false,
        hidden = false,
      },
      untracked = {
        folded = false,
        hidden = false,
      },
      unstaged = {
        folded = false,
        hidden = false,
      },
      staged = {
        folded = false,
        hidden = false,
      },
      stashes = {
        folded = true,
        hidden = false,
      },
      unpulled_upstream = {
        folded = true,
        hidden = false,
      },
      unmerged_upstream = {
        folded = false,
        hidden = false,
      },
      unpulled_pushRemote = {
        folded = true,
        hidden = false,
      },
      unmerged_pushRemote = {
        folded = false,
        hidden = false,
      },
      recent = {
        folded = true,
        hidden = false,
      },
      rebase = {
        folded = true,
        hidden = false,
      },
    },
    ignored_settings = {},
    mappings = {
      commit_editor = {
        ["q"] = "Close",
        ["<c-c><c-c>"] = "Submit",
        ["<c-c><c-k>"] = "Abort",
        ["<m-p>"] = "PrevMessage",
        ["<m-n>"] = "NextMessage",
        ["<m-r>"] = "ResetMessage",
      },
      commit_editor_I = {
        ["<c-c><c-c>"] = "Submit",
        ["<c-c><c-k>"] = "Abort",
      },
      rebase_editor = {
        ["p"] = "Pick",
        ["r"] = "Reword",
        ["e"] = "Edit",
        ["s"] = "Squash",
        ["f"] = "Fixup",
        ["x"] = "Execute",
        ["d"] = "Drop",
        ["b"] = "Break",
        ["q"] = "Close",
        ["<cr>"] = "OpenCommit",
        ["gk"] = "MoveUp",
        ["gj"] = "MoveDown",
        ["<c-c><c-c>"] = "Submit",
        ["<c-c><c-k>"] = "Abort",
        ["[c"] = "OpenOrScrollUp",
        ["]c"] = "OpenOrScrollDown",
      },
      rebase_editor_I = {
        ["<c-c><c-c>"] = "Submit",
        ["<c-c><c-k>"] = "Abort",
      },
      finder = {
        ["<cr>"] = "Select",
        ["<c-c>"] = "Close",
        ["<esc>"] = "Close",
        ["<c-n>"] = "Next",
        ["<c-p>"] = "Previous",
        ["<down>"] = "Next",
        ["<up>"] = "Previous",
        ["<tab>"] = "InsertCompletion",
        ["<space>"] = "MultiselectToggleNext",
        ["<s-space>"] = "MultiselectTogglePrevious",
        ["<c-j>"] = "NOP",
        ["<ScrollWheelDown>"] = "ScrollWheelDown",
        ["<ScrollWheelUp>"] = "ScrollWheelUp",
        ["<ScrollWheelLeft>"] = "NOP",
        ["<ScrollWheelRight>"] = "NOP",
        ["<LeftMouse>"] = "MouseClick",
        ["<2-LeftMouse>"] = "NOP",
      },
      refs_view = {
        ["x"] = "DeleteBranch",
      },
      popup = {
        ["?"] = "HelpPopup",
        ["A"] = "CherryPickPopup",
        ["d"] = "DiffPopup",
        ["M"] = "RemotePopup",
        ["P"] = "PushPopup",
        ["X"] = "ResetPopup",
        ["Z"] = "StashPopup",
        ["i"] = "IgnorePopup",
        ["t"] = "TagPopup",
        ["b"] = "BranchPopup",
        ["B"] = "BisectPopup",
        ["w"] = "WorktreePopup",
        ["c"] = "CommitPopup",
        ["f"] = "FetchPopup",
        ["l"] = "LogPopup",
        ["m"] = "MergePopup",
        ["p"] = "PullPopup",
        ["r"] = "RebasePopup",
        ["v"] = "RevertPopup",
      },
      status = {
        ["j"] = "MoveDown",
        ["k"] = "MoveUp",
        ["o"] = "OpenTree",
        ["q"] = "Close",
        ["I"] = "InitRepo",
        ["1"] = "Depth1",
        ["2"] = "Depth2",
        ["3"] = "Depth3",
        ["4"] = "Depth4",
        ["Q"] = "Command",
        ["<tab>"] = "Toggle",
        ["x"] = "Discard",
        ["s"] = "Stage",
        ["S"] = "StageUnstaged",
        ["<c-s>"] = "StageAll",
        ["u"] = "Unstage",
        ["K"] = "Untrack",
        ["R"] = "Rename",
        ["U"] = "UnstageStaged",
        ["y"] = "ShowRefs",
        ["$"] = "CommandHistory",
        ["Y"] = "YankSelected",
        ["<c-r>"] = "RefreshBuffer",
        ["<cr>"] = "GoToFile",
        ["<s-cr>"] = "PeekFile",
        ["<c-v>"] = "VSplitOpen",
        ["<c-x>"] = "SplitOpen",
        ["<c-t>"] = "TabOpen",
        ["{"] = "GoToPreviousHunkHeader",
        ["}"] = "GoToNextHunkHeader",
        ["[c"] = "OpenOrScrollUp",
        ["]c"] = "OpenOrScrollDown",
        ["<c-k>"] = "PeekUp",
        ["<c-j>"] = "PeekDown",
        ["<c-n>"] = "NextSection",
        ["<c-p>"] = "PreviousSection",
      },
    },
  }
end

M.values = M.get_default_values()

---Validates the config
---@return { [string]: string } all error messages emitted during validation
function M.validate_config()
  local config = M.values

  ---@type { [string]: string }
  local errors = {}
  local function err(value, msg)
    errors[value] = msg
  end

  ---Checks if a variable is the correct, type if not it calls err with an error string
  ---@param value any
  ---@param name string
  ---@param expected_types type | type[]
  local function validate_type(value, name, expected_types)
    if type(expected_types) == "table" then
      if not vim.tbl_contains(expected_types, type(value)) then
        err(
          name,
          string.format(
            "Expected `%s` to be one of types '%s', got '%s'",
            name,
            table.concat(expected_types, ", "),
            type(value)
          )
        )
        return false
      end
      return true
    end

    if type(value) ~= expected_types then
      err(
        name,
        string.format("Expected `%s` to be of type '%s', got '%s'", name, expected_types, type(value))
      )
      return false
    end
    return true
  end

  -- More complex validation functions go below
  local function validate_kind(val, name)
    if
      validate_type(val, name, "string")
      and not vim.tbl_contains({
        "split",
        "vsplit",
        "split_above",
        "split_above_all",
        "split_below",
        "split_below_all",
        "vsplit_left",
        "tab",
        "floating",
        "floating_console",
        "replace",
        "auto",
      }, val)
    then
      err(
        name,
        string.format(
          "Expected `%s` to be one of 'split', 'vsplit', 'split_above', 'vsplit_left', tab', 'floating', 'replace' or 'auto', got '%s'",
          name,
          val
        )
      )
    end
  end

  local function validate_signs()
    if not validate_type(config.signs, "signs", "table") then
      return
    end

    local function validate_signs_table(tbl_name, tbl)
      tbl_name = string.format("signs.%s", tbl_name)
      if type(tbl) ~= "table" then
        err(tbl_name, string.format("Expected `%s` to be of type 'table'!", tbl_name))
      else
        if #tbl ~= 2 then
          err(
            tbl_name,
            string.format("Expected for `%s` to be %s elements, it had %s elements!", tbl_name, #tbl, #tbl)
          )
        elseif type(tbl[1]) ~= "string" then
          err(
            tbl_name,
            string.format(
              "Expected element one of `%s` to be of type 'string', it was of type '%s'",
              tbl_name,
              tbl[1],
              type(tbl[1])
            )
          )
        elseif type(tbl[2]) ~= "string" then
          err(
            tbl_name,
            string.format(
              "Expected element two of `%s` to be of type 'string', it was of type '%s'",
              tbl_name,
              tbl[2],
              type(tbl[2])
            )
          )
        end
      end
    end

    validate_signs_table("hunk", config.signs.hunk)
    validate_signs_table("item", config.signs.item)
    validate_signs_table("section", config.signs.section)
  end

  local function validate_trinary_auto(value, name)
    local err_msg =
      string.format("Expected '%s' to be either a string with value 'auto' or a boolean value", name)
    if type(value) == "string" then
      if value ~= "auto" then
        err(name, err_msg)
      end
    elseif type(value) ~= "boolean" then
      err(name, err_msg)
    end
  end

  local function validate_integrations()
    local valid_integrations = { "diffview", "telescope", "fzf_lua", "mini_pick" }
    if not validate_type(config.integrations, "integrations", "table") or #config.integrations == 0 then
      return
    end
    for integration_name, _ in pairs(config.integrations) do
      if not vim.tbl_contains(valid_integrations, integration_name) then
        err(
          "valid_integrations." .. integration_name,
          string.format(
            "Expected a valid integration, received '%s', which is not a supported integration! Valid integrations: ",
            integration_name,
            table.concat(valid_integrations, ", ")
          )
        )
      end
    end
  end

  local function validate_sections()
    if not validate_type(config.sections, "sections", "table") then
      return
    end

    for section_name, section in pairs(config.sections) do
      validate_type(section, "section." .. section_name, "table")
      validate_type(section.folded, string.format("section.%s.folded", section_name), "boolean")
      validate_type(section.hidden, string.format("section.%s.hidden", section_name), "boolean")
    end
  end

  local function validate_highlights()
    if not validate_type(config.highlight, "highlight", "table") then
      return
    end

    for field, value in ipairs(config.highlight) do
      if field == "bold" or field == "italic" or field == "underline" then
        validate_type(value, string.format("highlight.%s", field), "boolean")
      else
        validate_type(value, string.format("highlight.%s", field), "string")

        if not string.match(value, "#%x%x%x%x%x%x") then
          err("highlight", string.format("Color value is not valid CSS: %s", value))
        end
      end
    end
  end

  local function validate_ignored_settings()
    if not validate_type(config.ignored_settings, "ignored_settings", "table") then
      return
    end

    for _, setting in ipairs(config.ignored_settings) do
      if validate_type(setting, "ignored_settings." .. vim.inspect(setting), "string") then
        local match_pattern = ".+%-%-.?"
        if not string.match(setting, match_pattern) then
          err(
            "ignored_settings",
            string.format(
              "An ignored_settings setting did not match %s (format: filetype--flag), setting was: %s",
              match_pattern,
              setting
            )
          )
        end
      end
    end
  end

  local function validate_mappings()
    if not validate_type(config.mappings, "mappings", "table") then
      return
    end

    -- Validate mappings.finder
    local valid_finder_commands = {
      false,
    }

    for _, cmd in pairs(M.get_default_values().mappings.finder) do
      table.insert(valid_finder_commands, cmd)
    end

    local function validate_finder_map(command, key)
      if
        not validate_type(key, string.format("mappings.finder -> %s", vim.inspect(key)), "string")
        or not validate_type(
          command,
          string.format("mappings.finder[%s]", vim.inspect(command)),
          { "string", "boolean" }
        )
      then
        return
      end

      if not vim.tbl_contains(valid_finder_commands, command) then
        local valid_finder_commands = util.map(valid_finder_commands, function(command)
          return vim.inspect(command)
        end)

        err(
          string.format("mappings.finder[%s] -> %s", vim.inspect(key), vim.inspect(command)),

          string.format(
            "Expected a valid finder command, got %s. Valid finder commands: { %s }",
            vim.inspect(command),
            table.concat(valid_finder_commands, ", ")
          )
        )
      end
    end

    if validate_type(config.mappings.finder, "mappings.finder", "table") then
      for key, command in pairs(config.mappings.finder) do
        validate_finder_map(command, key)
      end
    end

    -- Validate mappings.status
    local valid_status_commands = {
      false,
    }

    for _, cmd in pairs(M.get_default_values().mappings.status) do
      table.insert(valid_status_commands, cmd)
    end

    if validate_type(config.mappings.status, "mappings.status", "table") then
      for key, command in pairs(config.mappings.status) do
        if
          validate_type(key, "mappings.status -> " .. vim.inspect(key), "string")
          and validate_type(
            command,
            string.format("mappings.status['%s']", key),
            { "string", "boolean", "function" }
          )
        then
          if type(command) == "string" and not vim.tbl_contains(valid_status_commands, command) then
            local valid_status_commands = util.map(valid_status_commands, function(command)
              return vim.inspect(command)
            end)

            err(
              string.format("mappings.status['%s']", key),
              string.format(
                "Expected a valid status command, got '%s'. Valid status commands: { %s }",
                command,
                table.concat(valid_status_commands, ", ")
              )
            )
          end
        end
      end
    end

    local valid_popup_commands = {
      false,
    }

    for _, cmd in pairs(M.get_default_values().mappings.popup) do
      table.insert(valid_popup_commands, cmd)
    end

    if validate_type(config.mappings.popup, "mappings.popup", "table") then
      for key, command in pairs(config.mappings.popup) do
        if
          validate_type(key, "mappings.popup -> " .. vim.inspect(key), "string")
          and validate_type(command, string.format("mappings.popup['%s']", key), { "string", "boolean" })
        then
          if type(command) == "string" and not vim.tbl_contains(valid_popup_commands, command) then
            local valid_popup_commands = util.map(valid_popup_commands, function(command)
              return vim.inspect(command)
            end)

            err(
              string.format("mappings.popup['%s']", key),
              string.format(
                "Expected a valid popup command, got '%s'. Valid popup commands: { %s }",
                command,
                table.concat(valid_popup_commands, ", ")
              )
            )
          end
        end
      end
    end

    local valid_rebase_editor_commands = {
      false,
    }

    for _, cmd in pairs(M.get_default_values().mappings.rebase_editor) do
      table.insert(valid_rebase_editor_commands, cmd)
    end

    if validate_type(config.mappings.rebase_editor, "mappings.rebase_editor", "table") then
      for key, command in pairs(config.mappings.rebase_editor) do
        if
          validate_type(key, "mappings.rebase_editor -> " .. vim.inspect(key), "string")
          and validate_type(
            command,
            string.format("mappings.rebase_editor['%s']", key),
            { "string", "boolean", "function" }
          )
        then
          if type(command) == "string" and not vim.tbl_contains(valid_rebase_editor_commands, command) then
            local valid_rebase_editor_commands = util.map(valid_rebase_editor_commands, function(command)
              return vim.inspect(command)
            end)

            err(
              string.format("mappings.rebase_editor['%s']", key),
              string.format(
                "Expected a valid rebase_editor command, got '%s'. Valid rebase_editor commands: { %s }",
                command,
                table.concat(valid_rebase_editor_commands, ", ")
              )
            )
          end
        end
      end
    end

    local valid_rebase_editor_I_commands = {
      false,
    }

    for _, cmd in pairs(M.get_default_values().mappings.rebase_editor_I) do
      table.insert(valid_rebase_editor_I_commands, cmd)
    end

    if validate_type(config.mappings.rebase_editor_I, "mappings.rebase_editor_I", "table") then
      for key, command in pairs(config.mappings.rebase_editor_I) do
        if
          validate_type(key, "mappings.rebase_editor_I -> " .. vim.inspect(key), "string")
          and validate_type(
            command,
            string.format("mappings.rebase_editor_I['%s']", key),
            { "string", "boolean", "function" }
          )
        then
          if type(command) == "string" and not vim.tbl_contains(valid_rebase_editor_I_commands, command) then
            local valid_rebase_editor_I_commands = util.map(valid_rebase_editor_I_commands, function(command)
              return vim.inspect(command)
            end)

            err(
              string.format("mappings.rebase_editor_I['%s']", key),
              string.format(
                "Expected a valid rebase_editor_I command, got '%s'. Valid rebase_editor_I commands: { %s }",
                command,
                table.concat(valid_rebase_editor_I_commands, ", ")
              )
            )
          end
        end
      end
    end

    local valid_commit_editor_I_commands = {
      false,
    }

    for _, cmd in pairs(M.get_default_values().mappings.commit_editor_I) do
      table.insert(valid_commit_editor_I_commands, cmd)
    end

    if validate_type(config.mappings.commit_editor_I, "mappings.commit_editor_I", "table") then
      for key, command in pairs(config.mappings.commit_editor_I) do
        if
          validate_type(key, "mappings.commit_editor_I -> " .. vim.inspect(key), "string")
          and validate_type(
            command,
            string.format("mappings.commit_editor_I['%s']", key),
            { "string", "boolean", "function" }
          )
        then
          if type(command) == "string" and not vim.tbl_contains(valid_commit_editor_I_commands, command) then
            local valid_commit_editor_I_commands = util.map(valid_commit_editor_I_commands, function(command)
              return vim.inspect(command)
            end)

            err(
              string.format("mappings.commit_editor_I['%s']", key),
              string.format(
                "Expected a valid commit_editor_I command, got '%s'. Valid commit_editor_I commands: { %s }",
                command,
                table.concat(valid_commit_editor_I_commands, ", ")
              )
            )
          end
        end
      end
    end

    local valid_commit_editor_commands = {
      false,
    }

    for _, cmd in pairs(M.get_default_values().mappings.commit_editor) do
      table.insert(valid_commit_editor_commands, cmd)
    end

    if validate_type(config.mappings.commit_editor, "mappings.commit_editor", "table") then
      for key, command in pairs(config.mappings.commit_editor) do
        if
          validate_type(key, "mappings.commit_editor -> " .. vim.inspect(key), "string")
          and validate_type(
            command,
            string.format("mappings.commit_editor['%s']", key),
            { "string", "boolean", "function" }
          )
        then
          if type(command) == "string" and not vim.tbl_contains(valid_commit_editor_commands, command) then
            local valid_commit_editor_commands = util.map(valid_commit_editor_commands, function(command)
              return vim.inspect(command)
            end)

            err(
              string.format("mappings.commit_editor['%s']", key),
              string.format(
                "Expected a valid commit_editor command, got '%s'. Valid commit_editor commands: { %s }",
                command,
                table.concat(valid_commit_editor_commands, ", ")
              )
            )
          end
        end
      end
    end
  end

  if validate_type(config, "base config", "table") then
    validate_type(config.disable_hint, "disable_hint", "boolean")
    validate_type(config.disable_context_highlighting, "disable_context_highlighting", "boolean")
    validate_type(config.disable_signs, "disable_signs", "boolean")
    validate_type(config.telescope_sorter, "telescope_sorter", "function")
    validate_type(config.use_per_project_settings, "use_per_project_settings", "boolean")
    validate_type(config.remember_settings, "remember_settings", "boolean")
    validate_type(config.sort_branches, "sort_branches", "string")
    validate_type(config.initial_branch_name, "initial_branch_name", "string")
    validate_type(config.notification_icon, "notification_icon", "string")
    validate_type(config.console_timeout, "console_timeout", "number")
    validate_kind(config.kind, "kind")
    if validate_type(config.floating, "floating", "table") then
      validate_type(config.floating.relative, "relative", "string")
      validate_type(config.floating.width, "width", "number")
      validate_type(config.floating.height, "height", "number")
      validate_type(config.floating.style, "style", "string")
      validate_type(config.floating.border, "border", "string")
    end
    validate_type(config.disable_line_numbers, "disable_line_numbers", "boolean")
    validate_type(config.disable_relative_line_numbers, "disable_relative_line_numbers", "boolean")
    validate_type(config.auto_show_console, "auto_show_console", "boolean")
    validate_type(config.auto_show_console_on, "auto_show_console_on", "string")
    validate_type(config.auto_close_console, "auto_close_console", "boolean")
    if validate_type(config.status, "status", "table") then
      validate_type(config.status.show_head_commit_hash, "status.show_head_commit_hash", "boolean")
      validate_type(config.status.recent_commit_count, "status.recent_commit_count", "number")
      validate_type(config.status.mode_padding, "status.mode_padding", "number")
      validate_type(config.status.HEAD_padding, "status.HEAD_padding", "number")
      validate_type(config.status.mode_text, "status.mode_text", "table")
    end
    validate_signs()
    validate_trinary_auto(config.disable_insert_on_commit, "disable_insert_on_commit")
    -- Commit Editor
    if validate_type(config.commit_editor, "commit_editor", "table") then
      validate_type(config.commit_editor.show_staged_diff, "show_staged_diff", "boolean")
      validate_type(config.commit_editor.spell_check, "spell_check", "boolean")
      validate_kind(config.commit_editor.kind, "commit_editor")
    end
    -- Commit Select View
    if validate_type(config.commit_select_view, "commit_select_view", "table") then
      validate_kind(config.commit_select_view.kind, "config.commit_select_view.kind")
    end
    -- Commit View
    if validate_type(config.commit_view, "commit_view", "table") then
      validate_kind(config.commit_view.kind, "commit_view.kind")
    end
    -- Log View
    if validate_type(config.log_view, "log_view", "table") then
      validate_kind(config.log_view.kind, "log_view.kind")
    end
    -- Rebase Editor
    if validate_type(config.rebase_editor, "rebase_editor", "table") then
      validate_kind(config.rebase_editor.kind, "rebase_editor.kind")
    end
    -- Reflog View
    if validate_type(config.reflog_view, "reflog_view", "table") then
      validate_kind(config.reflog_view.kind, "reflog_view.kind")
    end
    -- refs view
    if validate_type(config.refs_view, "refs_view", "table") then
      validate_kind(config.refs_view.kind, "refs_view.kind")
    end
    -- Merge Editor
    if validate_type(config.merge_editor, "merge_editor", "table") then
      validate_kind(config.merge_editor.kind, "merge_editor.kind")
    end
    -- Preview Buffer
    if validate_type(config.preview_buffer, "preview_buffer", "table") then
      validate_kind(config.preview_buffer.kind, "preview_buffer.kind")
    end
    -- Popup
    if validate_type(config.popup, "popup", "table") then
      validate_kind(config.popup.kind, "popup.kind")
    end

    validate_integrations()
    validate_sections()
    validate_ignored_settings()
    validate_mappings()
    validate_highlights()
  end

  return errors
end

---@param name string
---@return boolean
function M.check_integration(name)
  local logger = require("neogit.logger")
  local enabled = M.values.integrations[name]

  if enabled == nil or enabled == "auto" then
    local success, _ = pcall(require, name:gsub("_", "-"))
    logger.info(("[CONFIG] Found auto integration '%s = %s'"):format(name, success))
    return success
  end

  logger.info(("[CONFIG] Found explicit integration '%s' = %s"):format(name, enabled))
  return enabled
end

function M.setup(opts)
  if opts == nil then
    return
  end

  if opts.use_default_keymaps == false then
    M.values.mappings =
      { status = {}, popup = {}, finder = {}, commit_editor = {}, rebase_editor = {}, refs_view = {} }
  else
    -- Clear our any "false" user mappings from defaults
    for section, maps in pairs(opts.mappings or {}) do
      for k, v in pairs(maps) do
        if v == false then
          M.values.mappings[section][k] = nil
          opts.mappings[section][k] = nil
        end
      end
    end
  end

  M.values = vim.tbl_deep_extend("force", M.values, opts)

  local config_errs = M.validate_config()
  if vim.tbl_count(config_errs) == 0 then
    return
  end
  local header = "====Neogit Configuration Errors===="
  local header_message = {
    "Neogit has NOT been setup!",
    "You have a misconfiguration in your Neogit setup!",
    'Validate that your configuration passed to `require("neogit").setup()` is valid!',
  }
  local header_sep = ""
  for _ = 0, string.len(header), 1 do
    header_sep = header_sep .. "-"
  end

  local config_errs_message = {}
  for config_key, err in pairs(config_errs) do
    table.insert(config_errs_message, string.format("Config value: `%s` had error -> %s", config_key, err))
  end
  error(
    string.format(
      "\n%s\n%s\n%s\n%s",
      header,
      table.concat(header_message, "\n"),
      header_sep,
      table.concat(config_errs_message, "\n")
    ),
    vim.log.levels.ERROR
  )
end

return M
