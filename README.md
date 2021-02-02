# Neogit

A *work-in-progress* Magit clone for Neovim that is geared toward the Vim philosophy.

## Installation

| Plugin Manager                                       | Command                                                                        |
|------------------------------------------------------|--------------------------------------------------------------------------------|
| [Packer](https://github.com/wbthomason/packer.nvim)  | `  use 'TimUntersberger/neogit'`                                               |
| [Vim-plug](https://github.com/junegunn/vim-plug)     | `Plug 'TimUntersberger/neogit'`                                                |
| [NeoBundle](https://github.com/Shougo/neobundle.vim) | `NeoBundle 'TimUntersberger/neogit'`                                           |
| [Vundle](https://github.com/VundleVim/Vundle.vim)    | `Bundle 'TimUntersberger/neogit'`                                              |
| [Pathogen](https://github.com/tpope/vim-pathogen)    | `git clone https://github.com/TimUntersberger/neogit.git ~/.vim/bundle/neogit` |
| [Dein](https://github.com/Shougo/dein.vim)           | `call dein#add('TimUntersberger/neogit')`                                      |

You also use in the built-in package manager:
`$ git clone --depth 1 https://github.com/TimUntersberger/neogit $XDG_CONFIG_HOME/nvim/pack/plugins/start/neogit`

## Usage

You can either open neogit by using the `Neogit` command or using the lua api:

```lua
local neogit = require('neogit')

neogit.status.create(<kind>)
```

The create function takes 1 optional argument that can be one of the following values:

* tab (default)
* floating
* split


## Status Keybindings

$ - command history

1, 2, 3, 4 - set foldlevel

tab - toggle diff

s - stage (also supports staging selection/hunk)

S - stage unstaged changes

ctrl s - stage everything

ctrl r - refresh buffer

u - unstage (also supports unstaging selection/hunk)

U - unstage staged changes

c - open commit popup

ctrl-c ctrl-c - commit (when writing the message)

L - open log popup

P - open push popup

p - open pull popup

x - discard changes (also supports discarding hunks)


## Contextual Highlighting

The colors for contextual highlighting are defined with these highlight groups:
```viml
hi def NeogitDiffAddHighlight guibg=#404040
hi def NeogitDiffDeleteHighlight guibg=#404040
hi def NeogitDiffContextHighlight ctermbg=4 guibg=#333333
hi def NeogitHunkHeader guifg=#cccccc guibg=#404040
hi def NeogitHunkHeaderHighlight guifg=#cccccc guibg=#4d4d4d
```
You can override them to fit your colorscheme by creating a `syntax/NeogitStatus.vim` in your vim configuration.

## Todo

The todo file does not represent ALL of the missing features. This file just shows the features which I noticed were missing and I have to implement. This file will grow in the future.

[TODO](./todo.md)
