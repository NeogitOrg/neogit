# Neogit

![preview](https://github.com/NeogitOrg/neogit/assets/7228095/d964cbb4-a557-4e97-ac5b-ea571a001f5c)


A **work-in-progress** [Magit](https://magit.vc) clone for [Neovim](https://neovim.io) that is geared toward the Vim philosophy.


## Installation

Here's an example spec for [Lazy](https://github.com/folke/lazy.nvim), but you're free to use whichever plugin manager suits you.

```lua
{
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",         -- required
    "nvim-telescope/telescope.nvim", -- optional
    "sindrets/diffview.nvim",        -- optional
  },
  config = true
}
```

If you're not using lazy, you'll need to require and setup the plugin like so:

```lua
-- init.lua
local neogit = require('neogit')
neogit.setup {}
```

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

-- open commit popup
neogit.open({ "commit" })

-- open with split kind
neogit.open({ kind = "split" })

-- open home directory
neogit.open({ cwd = "~" })
```

The `kind` option can be one of the following values:
- `tab`      (default)
- `replace`
- `floating` (EXPERIMENTAL! This currently doesn't work with popups. Very unstable)
- `split`
- `split_above`
- `vsplit`
- `auto` (`vsplit` if window would have 80 cols, otherwise `split`)

## Status Keybindings

| Keybinding   | Function                                         |
|--------------|--------------------------------------------------|
| Tab          | Toggle diff/section                              |
| 1, 2, 3, 4   | Set a foldlevel                                  |
| $            | Command history                                  |
| s            | Stage (also supports staging selection/hunk)     |
| S            | Stage unstaged changes                           |
| \<c-s>       | Stage Everything                                 |
| u            | Unstage (also supports staging selection/hunk)   |
| U            | Unstage staged changes                           |
| x            | Discard changes (also supports discarding hunks) |
| d            | Open `diffview.nvim` at hovered file             |
| c            | Open commit popup                                |
| b            | Branch popup                                     |
| r            | Open rebase popup                                |
| m            | Open merge popup                                 |
| L            | Open log popup                                   |
| f            | Open fetch popup                                 |
| p            | Open pull popup                                  |
| P            | Open push popup                                  |
| Z            | Open stash popup                                 |
| X            | Open reset popup                                 |
| A            | Open cherry pick popup                           |
| v            | Open revert popup                                |
| ?            | Open help popup                                  |
| D            | Open diff popup                                  |
| \<enter>     | Go to file                                       |
| \<c-r>       | Refresh Buffer                                   |


## Configuration

You can configure neogit by running the `neogit.setup` function.

```lua
local neogit = require("neogit")

neogit.setup {
  disable_signs = false,
  disable_hint = false,
  disable_context_highlighting = false,
  disable_commit_confirmation = false,
  -- Neogit refreshes its internal state after specific events, which can be expensive depending on the repository size.
  -- Disabling `auto_refresh` will make it so you have to manually refresh the status after you open it.
  auto_refresh = true,
  -- Value used for `--sort` option for `git branch` command
  -- By default, branches will be sorted by commit date descending
  -- Flag description: https://git-scm.com/docs/git-branch#Documentation/git-branch.txt---sortltkeygt
  -- Sorting keys: https://git-scm.com/docs/git-for-each-ref#_options
  sort_branches = "-committerdate",
  disable_builtin_notifications = false,
  -- Allows a different telescope sorter. Defaults to 'fuzzy_with_index_bias'. The example
  -- below will use the native fzf sorter instead.
  telescope_sorter = function()
    return require("telescope").extensions.fzf.native_fzf_sorter()
  end,
  -- Change the default way of opening neogit
  kind = "tab",
  -- The time after which an output console is shown for slow running commands
  console_timeout = 2000,
  -- Automatically show console if a command takes more than console_timeout milliseconds
  auto_show_console = true,
  -- Persist the values of switches/options within and across sessions
  remember_settings = true,
  -- Scope persisted settings on a per-project basis
  use_per_project_settings = true,
  -- Array-like table of settings to never persist. Uses format "Filetype--cli-value"
  --   ie: `{ "NeogitCommitPopup--author", "NeogitCommitPopup--no-verify" }`
  ignored_settings = {},
  -- Change the default way of opening the commit popup
  commit_popup = {
    kind = "split",
  },
  -- Change the default way of opening the preview buffer
  preview_buffer = {
    kind = "split",
  },
  -- Change the default way of opening popups
  popup = {
    kind = "split",
  },
  -- customize displayed signs
  signs = {
    -- { CLOSED, OPENED }
    section = { ">", "v" },
    item = { ">", "v" },
    hunk = { "", "" },
  },
  -- Each Integration is auto-detected through plugin presence. Disabled by setting to `false`
  integrations = {
    -- If enabled, use telescope for menu selection rather than vim.ui.select.
    -- Allows multi-select and some things that vim.ui.select doesn't.
    telescope = nil,

    -- Neogit only provides inline diffs. If you want a more traditional way to look at diffs, you can use `sindrets/diffview.nvim`.
    -- The diffview integration enables the diff popup, which is a wrapper around `sindrets/diffview.nvim`.
    --
    -- Requires you to have `sindrets/diffview.nvim` installed.
    diffview = nil,
  },
  -- Setting any section to `false` will make the section not render at all
  sections = {
    untracked = {
      folded = false
    },
    unstaged = {
      folded = false
    },
    staged = {
      folded = false
    },
    stashes = {
      folded = true
    },
    unpulled = {
      folded = true
    },
    unmerged = {
      folded = false
    },
    recent = {
      folded = true
    },
  },
  -- override/add mappings
  mappings = {
    -- modify status buffer mappings
    status = {
      -- Adds a mapping with "B" as key that does the "BranchPopup" command
      ["B"] = "BranchPopup",
      -- Removes the default mapping of "s"
      ["s"] = false,
      ...
    },
    -- Modify fuzzy-finder buffer mappings
    finder = {
      -- Binds <cr> to trigger select action
      ["<cr>"] = "Select",
      ...
    }
  }
}
```

## Buffers

### Log Buffer

`Ll`

Shows a graph over the commit history.

You can perform an action over the commit underneath the cursor by opening one of the available popups, such at `b` for branch.

#### Shortcuts
- `bb` checkout commit under cursor
- `d` open Diffview
- `<Tab>` expand commit
- `<Enter>` open commit diff
- `v` Revert commit
- `c` Targeted commit
- `A` cherry pick
- 

### List of status commands:
* Close
* InitRepo
* Depth1 (Set foldlevel to 1)
* Depth2 (Set foldlevel to 2)
* Depth3 (Set foldlevel to 3)
* Depth4 (Set foldlevel to 4)
* Toggle
* Discard (Normal and visual mode)
* Stage (Normal and visual mode)
* StageUnstaged
* StageAll
* GoToFile
* GoToPreviousHunkHeader
* GoToNextHunkHeader
* Unstage (Normal and visual mode)
* UnstageStaged
* CommandHistory
* RefreshBuffer
* HelpPopup
* PullPopup
* PushPopup
* FetchPopup
* ResetPopup
* CommitPopup
* LogPopup
* StashPopup
* BranchPopup
* MergePopup
* CherryPickPopup (Normal and visual mode)
* RevertPopup (Normal and visual mode)

### List of fuzzy-finder commands:
* Select
* Close
* Next
* Previous
* NOP
* MultiselectToggleNext
* MultiselectTogglePrevious

## Highlight Groups

See the built-in documentation for a comprehensive list of highlight groups. If your theme doesn't style a particular group, we'll try our best to do a nice job.

## Disabling Hint

Set `disable_hint = true` in your call to [`setup`](#configuration) to hide hints on top of the panel.

## Disabling Commit Confirmation

Set `disable_commit_confirmation = true` in your call to [`setup`](#configuration) to disable the "Are you sure you want to commit?" prompt after saving the commit message buffer.

## Disabling Insert On Commit

Set `disable_insert_on_commit = true` in your call to [`setup`](#configuration) to disable automatically changing to insert mode when opening the commit message buffer. (Disabled is the default)

Set `disable_insert_on_commit = "auto"` to enter insert mode _if_ the commit message is empty - otherwise stay in normal mode.

## Events

Neogit emits the following events:

| Event                   | Description                      |
|-------------------------|----------------------------------|
| `NeogitStatusRefreshed` | Status has been reloaded         |
| `NeogitCommitComplete`  | Commit has been created          |
| `NeogitPushComplete`    | Push has completed               |
| `NeogitPullComplete`    | Pull has completed               |
| `NeogitFetchComplete`   | Fetch has completed              |

You can listen to the events using the following code:

```vim
autocmd User NeogitStatusRefreshed echo "Hello World!"
```

Or, if you prefer to configure autocommands via Lua:

```lua
local group = vim.api.nvim_create_augroup('MyCustomNeogitEvents', { clear = true })
vim.api.nvim_create_autocmd('User', {
  pattern = 'NeogitPushComplete',
  group = group,
  callback = require('neogit').close,
})
```

## Refreshing Neogit

If you would like to refresh Neogit manually, you can use `neogit#refresh_manually` in Vimscript or `require('neogit').refresh_manually` in lua. They both require a single file parameter.

This allows you to refresh Neogit on your own custom events

```vim
augroup DefaultRefreshEvents
  au!
  au BufWritePost,BufEnter,FocusGained,ShellCmdPost,VimResume * call <SID>neogit#refresh_manually(expand('<afile>'))
augroup END
```

## Testing

Run `make test` after checking out the repo. All dependencies should get automatically downloaded to `/tmp/neogit-test/`

See [CONTRIBUTING.md](https://github.com/NeogitOrg/neogit/edit/master/CONTRIBUTING.md) for more details
