## General

* refactor: extract buffers like "NeogitLog" into their own files
* feat: floating windows

## Commit

* feat: save commit messages in memory
* feat: make it possible to go through previous commit messages when writing one

## Status

* feat: contextually retain cursor position (WIP)
* feat: git restore
* fix: unstage/stage all don't check for existing entries
* change: 1/2/3/4 are local to section
* feat: add M-1/M-2/M-3/M-3 as global versions

## Push

## Popups

* chore: rename popup -> transient
* refactor: action/switch/option/config should all exist on the same list within state, allowing better control over
  ordering. Heading should be added as a component type too. Existing methods should just specify which component should
  be used to render it - kinda OO style. This would let us remove some if-checks for the headings, as well as
  consolidate config-headings and action headings into the same component (which they are, essentially)

## Buffer

## Workflow (Not sure)

* feat: support creating branches based on a predefined model (something like feature branches)

## Highlighting

## Process
Rewrite process to use `vim.system` instead of `vim.fn.jobstart`
https://github.com/neovim/neovim/commit/c0952e62fd0ee16a3275bb69e0de04c836b39015
https://github.com/neovim/neovim/blob/1de82e16c1216e1dbe22cf7a8ec9ea9e9e69b631/runtime/lua/vim/_editor.lua#L84
https://github.com/nvim-treesitter/nvim-treesitter/pull/4921/files
https://github.com/neovim/neovim/pull/23827
