<div align="center">
    <div>
        <div><img src="https://github.com/NeogitOrg/neogit/assets/7228095/7684545f-47b5-40e2-aedd-ccf56e0553f4" width="400px"/></div>
        <div><h1>Neogit</h1></div>
    </div>
    <table>
        <tr>
            <td>
                <strong>A git interface for <a href="https://neovim.io">Neovim</a>, inspired by <a href="https://magit.vc">Magit</a>.</strong>
            </td>
        </tr>
    </table>

  [![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
  [![Neovim](https://img.shields.io/badge/Neovim%200.10+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)
  [![MIT](https://img.shields.io/badge/MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
  <a href="https://dotfyle.com/plugins/NeogitOrg/neogit">
    <img src="https://dotfyle.com/plugins/NeogitOrg/neogit/shield?style=for-the-badge" />
  </a>
</div>


![preview](https://github.com/NeogitOrg/neogit/assets/7228095/d964cbb4-a557-4e97-ac5b-ea571a001f5c)


## Installation

Here's an example spec for [Lazy](https://github.com/folke/lazy.nvim), but you're free to use whichever plugin manager suits you.

```lua
{
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",         -- required
    "sindrets/diffview.nvim",        -- optional - Diff integration

    -- Only one of these is needed.
    "nvim-telescope/telescope.nvim", -- optional
    "ibhagwan/fzf-lua",              -- optional
    "echasnovski/mini.pick",         -- optional
  },
}
```

## Compatibility

The `master` branch will always be compatible with the latest **stable** release of Neovim, and usually with the latest **nightly** build as well.

## Configuration

You can configure neogit by running the `require('neogit').setup {}` function, passing a table as the argument.

<details>
<summary>Default Config</summary>

```lua
local neogit = require("neogit")

neogit.setup {
  -- Hides the hints at the top of the status buffer
  disable_hint = false,
  -- Disables changing the buffer highlights based on where the cursor is.
  disable_context_highlighting = false,
  -- Disables signs for sections/items/hunks
  disable_signs = false,
  -- Offer to force push when branches diverge
  prompt_force_push = true,
  -- Changes what mode the Commit Editor starts in. `true` will leave nvim in normal mode, `false` will change nvim to
  -- insert mode, and `"auto"` will change nvim to insert mode IF the commit message is empty, otherwise leaving it in
  -- normal mode.
  disable_insert_on_commit = "auto",
  -- When enabled, will watch the `.git/` directory for changes and refresh the status buffer in response to filesystem
  -- events.
  filewatcher = {
    interval = 1000,
    enabled = true,
  },
  -- "ascii"   is the graph the git CLI generates
  -- "unicode" is the graph like https://github.com/rbong/vim-flog
  -- "kitty"   is the graph like https://github.com/isakbm/gitgraph.nvim - use https://github.com/rbong/flog-symbols if you don't use Kitty
  graph_style = "ascii",
  -- Show relative date by default. When set, use `strftime` to display dates
  commit_date_format = nil,
  log_date_format = nil,
  -- Show message with spinning animation when a git command is running.
  process_spinner = false,
  -- Used to generate URL's for branch popup action "pull request".
  git_services = {
    ["github.com"] = "https://github.com/${owner}/${repository}/compare/${branch_name}?expand=1",
    ["bitbucket.org"] = "https://bitbucket.org/${owner}/${repository}/pull-requests/new?source=${branch_name}&t=1",
    ["gitlab.com"] = "https://gitlab.com/${owner}/${repository}/merge_requests/new?merge_request[source_branch]=${branch_name}",
    ["azure.com"] = "https://dev.azure.com/${owner}/_git/${repository}/pullrequestcreate?sourceRef=${branch_name}&targetRef=${target}",
  },
  -- Allows a different telescope sorter. Defaults to 'fuzzy_with_index_bias'. The example below will use the native fzf
  -- sorter instead. By default, this function returns `nil`.
  telescope_sorter = function()
    return require("telescope").extensions.fzf.native_fzf_sorter()
  end,
  -- Persist the values of switches/options within and across sessions
  remember_settings = true,
  -- Scope persisted settings on a per-project basis
  use_per_project_settings = true,
  -- Table of settings to never persist. Uses format "Filetype--cli-value"
  ignored_settings = {},
  -- Configure highlight group features
  highlight = {
    italic = true,
    bold = true,
    underline = true
  },
  -- Set to false if you want to be responsible for creating _ALL_ keymappings
  use_default_keymaps = true,
  -- Neogit refreshes its internal state after specific events, which can be expensive depending on the repository size.
  -- Disabling `auto_refresh` will make it so you have to manually refresh the status after you open it.
  auto_refresh = true,
  -- Value used for `--sort` option for `git branch` command
  -- By default, branches will be sorted by commit date descending
  -- Flag description: https://git-scm.com/docs/git-branch#Documentation/git-branch.txt---sortltkeygt
  -- Sorting keys: https://git-scm.com/docs/git-for-each-ref#_options
  sort_branches = "-committerdate",
  -- Default for new branch name prompts
  initial_branch_name = "",
  -- Change the default way of opening neogit
  kind = "tab",
  -- Floating window style 
  floating = {
    relative = "editor",
    width = 0.8,
    height = 0.7,
    style = "minimal",
    border = "rounded",
  },
  -- Disable line numbers
  disable_line_numbers = true,
  -- Disable relative line numbers
  disable_relative_line_numbers = true,
  -- The time after which an output console is shown for slow running commands
  console_timeout = 2000,
  -- Automatically show console if a command takes more than console_timeout milliseconds
  auto_show_console = true,
  -- Automatically close the console if the process exits with a 0 (success) status
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
    -- Accepted values:
    -- "split" to show the staged diff below the commit editor
    -- "vsplit" to show it to the right
    -- "split_above" Like :top split
    -- "vsplit_left" like :vsplit, but open to the left
    -- "auto" "vsplit" if window would have 80 cols, otherwise "split"
    staged_diff_split_kind = "split",
    spell_check = true,
  },
  commit_select_view = {
    kind = "tab",
  },
  commit_view = {
    kind = "vsplit",
    verify_commit = vim.fn.executable("gpg") == 1, -- Can be set to true or false, otherwise we try to find the binary
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
    -- { CLOSED, OPENED }
    hunk = { "", "" },
    item = { ">", "v" },
    section = { ">", "v" },
  },
  -- Each Integration is auto-detected through plugin presence, however, it can be disabled by setting to `false`
  integrations = {
    -- If enabled, use telescope for menu selection rather than vim.ui.select.
    -- Allows multi-select and some things that vim.ui.select doesn't.
    telescope = nil,
    -- Neogit only provides inline diffs. If you want a more traditional way to look at diffs, you can use `diffview`.
    -- The diffview integration enables the diff popup.
    --
    -- Requires you to have `sindrets/diffview.nvim` installed.
    diffview = nil,

    -- If enabled, uses fzf-lua for menu selection. If the telescope integration
    -- is also selected then telescope is used instead
    -- Requires you to have `ibhagwan/fzf-lua` installed.
    fzf_lua = nil,

    -- If enabled, uses mini.pick for menu selection. If the telescope integration
    -- is also selected then telescope is used instead
    -- Requires you to have `echasnovski/mini.pick` installed.
    mini_pick = nil,
  },
  sections = {
    -- Reverting/Cherry Picking
    sequencer = {
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
    -- Setting any of these to `false` will disable the mapping.
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
```
</details>

## Usage

You can either open Neogit by using the `Neogit` command:

```vim
:Neogit             " Open the status buffer in a new tab
:Neogit cwd=<cwd>   " Use a different repository path
:Neogit cwd=%:p:h   " Uses the repository of the current file
:Neogit kind=<kind> " Open specified popup directly
:Neogit commit      " Open commit popup
```

Or using the lua api:

```lua
local neogit = require('neogit')

-- open using defaults
neogit.open()

-- open a specific popup
neogit.open({ "commit" })

-- open as a split
neogit.open({ kind = "split" })

-- open with different project
neogit.open({ cwd = "~" })
```

The `kind` option can be one of the following values:
- `tab`      (default)
- `replace`
- `split`
- `split_above`
- `split_above_all`
- `split_below`
- `split_below_all`
- `vsplit`
- `floating`
- `auto` (`vsplit` if window would have 80 cols, otherwise `split`)

## Popups

The following popup menus are available from all buffers:
- Bisect
- Branch + Branch Config
- Cherry Pick
- Commit
- Diff
- Fetch
- Ignore
- Log
- Merge
- Pull
- Push
- Rebase
- Remote + Remote Config
- Reset
- Revert
- Stash
- Tag
- Worktree

Many popups will use whatever is currently under the cursor or selected as input for an action. For example, to cherry-pick a range of commits from the log view, a linewise visual selection can be made, and using either `apply` or `pick` from the cherry-pick menu will use the selection.

This works for just about everything that has an object-ID in git, and if you find one that you think _should_ work but doesn't, open an issue :)

## Highlight Groups

See the built-in documentation for a comprehensive list of highlight groups. If your theme doesn't style a particular group, we'll try our best to do a nice job.


## Events

Neogit emits the following events:

| Event                   | Description                              | Event Data                                      |
|-------------------------|------------------------------------------|-------------------------------------------------|
| `NeogitStatusRefreshed` | Status has been reloaded                 | `{}`                                            |
| `NeogitCommitComplete`  | Commit has been created                  | `{}`                                            |
| `NeogitPushComplete`    | Push has completed                       | `{}`                                            |
| `NeogitPullComplete`    | Pull has completed                       | `{}`                                            |
| `NeogitFetchComplete`   | Fetch has completed                      | `{}`                                            |
| `NeogitBranchCreate`    | Branch was created, starting from `base` | `{ branch_name: string, base: string? }`        |
| `NeogitBranchDelete`    | Branch was deleted                       | `{ branch_name: string }`                       |
| `NeogitBranchCheckout`  | Branch was checked out                   | `{ branch_name: string }`                       |
| `NeogitBranchReset`     | Branch was reset to a commit/branch      | `{ branch_name: string, resetting_to: string }` |
| `NeogitBranchRename`    | Branch was renamed                       | `{ branch_name: string, new_name: string }`     |
| `NeogitRebase`        | A rebase finished                        | `{ commit: string, status: "ok"\|"conflict" }`    |
| `NeogitReset`         | A branch was reset to a certain commit   | `{ commit: string, mode: "soft"\|"mixed"\|"hard"\|"keep"\|"index" }` |
| `NeogitTagCreate`     | A tag was placed on a certain commit     | `{ name: string, ref: string }`                   |
| `NeogitTagDelete`     | A tag was removed                        | `{ name: string }`                                |
| `NeogitCherryPick`    | One or more commits were cherry-picked    | `{ commits: string[] }`                          |
| `NeogitMerge`         | A merge finished                          | `{ branch: string, args = string[], status: "ok"\|"conflict" }` |
| `NeogitStash`         | A stash finished                          | `{ success: boolean }` |

## Versioning

Neogit follows semantic versioning.

## Contributing

See [CONTRIBUTING.md](https://github.com/NeogitOrg/neogit/blob/master/CONTRIBUTING.md) for more details.

## Special Thanks

- [kolja](https://github.com/kolja) for the Neogit Logo
- [gitgraph.nvim](https://github.com/isakbm/gitgraph.nvim) for the "kitty" git graph renderer
- [vim-flog](https://github.com/rbong/vim-flog) for the "unicode" git graph renderer

