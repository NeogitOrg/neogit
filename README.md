# Neogit

![preview](https://user-images.githubusercontent.com/32014449/109874516-8042af00-7c6f-11eb-8afc-65ef52448c7a.png)

A **work-in-progress** [Magit](https://magit.vc) clone for [Neovim](https://neovim.io) that is geared toward the Vim philosophy.

## Installation

**NOTE**: We depend on [plenary.nvim](https://github.com/nvim-lua/plenary.nvim), so to use this plugin, you will additionally need to
require `nvim-lua/plenary.nvim` using your plugin manager of choice, before requiring this plugin.

| Plugin Manager                                       | Command                                                                        |
|------------------------------------------------------|--------------------------------------------------------------------------------|
| [Packer](https://github.com/wbthomason/packer.nvim)  | `use { 'TimUntersberger/neogit', requires = 'nvim-lua/plenary.nvim' }`          |
| [Vim-plug](https://github.com/junegunn/vim-plug)     | `Plug 'TimUntersberger/neogit'`                                                |
| [NeoBundle](https://github.com/Shougo/neobundle.vim) | `NeoBundle 'TimUntersberger/neogit'`                                           |
| [Vundle](https://github.com/VundleVim/Vundle.vim)    | `Bundle 'TimUntersberger/neogit'`                                              |
| [Pathogen](https://github.com/tpope/vim-pathogen)    | `git clone https://github.com/TimUntersberger/neogit.git ~/.vim/bundle/neogit` |
| [Dein](https://github.com/Shougo/dein.vim)           | `call dein#add('TimUntersberger/neogit')`                                      |

You also use in the built-in package manager:
```bash
$ git clone --depth 1 https://github.com/TimUntersberger/neogit $XDG_CONFIG_HOME/nvim/pack/plugins/start/neogit
```

Now you have to add the following lines to your `init.lua`

```lua
local neogit = require('neogit')

neogit.setup {}
```

## Usage

You can either open neogit by using the `Neogit` command 

```vim
:Neogit " uses tab
:Neogit kind=<kind> " override kind
:Neogit cwd=<cwd> " override cwd
:Neogit commit" open commit popup
```

or using the lua api:

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

The create function takes 1 optional argument that can be one of the following values:

* tab (default)
* replace
* floating (This currently doesn't work with popups. Very unstable)
* split
* split_above
* vsplit

## Status Keybindings

| Keybinding   | Function                                         |
|--------------|--------------------------------------------------|
| Tab          | Toggle diff                                      |
| 1, 2, 3, 4   | Set a foldlevel                                  |
| $            | Command history                                  |
| b            | Branch popup                                     |
| s            | Stage (also supports staging selection/hunk)     |
| S            | Stage unstaged changes                           |
| \<C-s>       | Stage Everything                                 |
| u            | Unstage (also supports staging selection/hunk)   |
| U            | Unstage staged changes                           |
| c            | Open commit popup                                |
| r            | Open rebase popup                                |
| L            | Open log popup                                   |
| p            | Open pull popup                                  |
| P            | Open push popup                                  |
| Z            | Open stash popup                                 |
| ?            | Open help popup                                  |
| x            | Discard changes (also supports discarding hunks) |
| \<enter>     | Go to file                                       |
| \<C-r>       | Refresh Buffer                                   |

With `diffview` integration enabled

| Keybinding   | Function                                         |
|--------------|--------------------------------------------------|
| d            | Open `diffview.nvim` at hovered file             |
| D (TODO)     | Open diff popup                                  |

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
  disable_builtin_notifications = false,
  use_magit_keybindings = false,
  commit_popup = {
      kind = "split",
  },
  -- Change the default way of opening neogit
  kind = "tab",
  -- customize displayed signs
  signs = {
    -- { CLOSED, OPENED }
    section = { ">", "v" },
    item = { ">", "v" },
    hunk = { "", "" },
  },
  integrations = {
    -- Neogit only provides inline diffs. If you want a more traditional way to look at diffs, you can use `sindrets/diffview.nvim`.
    -- The diffview integration enables the diff popup, which is a wrapper around `sindrets/diffview.nvim`.
    --
    -- Requires you to have `sindrets/diffview.nvim` installed.
    -- use { 
    --   'TimUntersberger/neogit', 
    --   requires = { 
    --     'nvim-lua/plenary.nvim',
    --     'sindrets/diffview.nvim' 
    --   }
    -- }
    --
    diffview = false  
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
      ["s"] = "",
    }
  }
}
```

Right now, only the status buffer supports custom mappings.

List of status commands:

* Close
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
* Unstage (Normal and visual mode)
* UnstageStaged
* CommandHistory
* RefreshBuffer
* HelpPopup
* PullPopup
* PushPopup
* CommitPopup
* LogPopup
* StashPopup
* BranchPopup

## Notification Highlighting

Neogit defines three highlight groups for the notifications:

```vim
hi NeogitNotificationInfo guifg=#80ff95
hi NeogitNotificationWarning guifg=#fff454
hi NeogitNotificationError guifg=#c44323
```

You can override them to fit your colorscheme in your vim configuration.

## Contextual Highlighting

The colors for contextual highlighting are defined with these highlight groups:

```vim
hi def NeogitDiffAddHighlight guibg=#404040 guifg=#859900
hi def NeogitDiffDeleteHighlight guibg=#404040 guifg=#dc322f
hi def NeogitDiffContextHighlight guibg=#333333 guifg=#b2b2b2
hi def NeogitHunkHeader guifg=#cccccc guibg=#404040
hi def NeogitHunkHeaderHighlight guifg=#cccccc guibg=#4d4d4d
```

You can override them to fit your colorscheme by creating a `syntax/NeogitStatus.vim` in your vim configuration and adding your custom highlights there.

### Disabling Contextual Highlighting

Set `disable_context_highlighting = true` in your call to [`setup`](#configuration) to disable context highlighting altogether.

## Disabling Hint
Set `disable_hint = true` in your call to [`setup`](#configuration) to hide hints on top of the panel.

## Disabling Commit Confirmation

Set `disable_commit_confirmation = true` in your call to [`setup`](#configuration) to disable the "Are you sure you want to commit?" prompt after saving the commit message buffer.

## Disabling Insert On Commit

Set `disable_insert_on_commit = true` in your call to [`setup`](#configuration) to disable automatically changing to insert mode when opening the commit message buffer. (Disabled is the default)

## Events

Neogit emits the following events:

| Event                   | Description                      |
|-------------------------|----------------------------------|
| `NeogitStatusRefreshed` | Status has been reloaded         |
| `NeogitCommitComplete`  | Commit has been created          |
| `NeogitPushComplete`    | Push has completed               |


You can listen to the events using the following code:

```vim
autocmd User NeogitStatusRefreshed echom "Hello World!"
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

## Magit-style Keybindings

Neogit uses 'p' for pulling instead of 'F'.

Set `use_magit_keybindings = true` in your call to [`setup`](#configuration) to use magit-style keybindings.

## Refreshing Neogit

If you would like to refresh Neogit manually, you can use `neogit#refresh_manually` in Vimscript or `require('neogit').refresh_manually` in lua. They both require a single file parameter.

This allows you to refresh Neogit on your own custom events

```vim
augroup DefaultRefreshEvents
  au!
  au BufWritePost,BufEnter,FocusGained,ShellCmdPost,VimResume * call <SID>neogit#refresh_manually(expand('<afile>'))
augroup END
```

## Todo

**Note: This file is no longer being updated.**

The todo file does not represent ALL of the missing features. This file just shows the features which I noticed were missing and I have to implement.

[TODO](./todo.md)

## Testing

Assure that you have [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) 
installed as a plugin for your neovim instance. Afterwards, run `make test`
to run the unit test suite.

Plenary uses it's own port of busted and a bundled luassert, so consult their
code and the respective [busted](http://olivinelabs.com/busted/) and 
[luassert](http://olivinelabs.com/busted/#asserts) docs for what methods are 
available.
