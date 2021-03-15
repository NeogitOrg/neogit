# Neogit

![preview](https://user-images.githubusercontent.com/32014449/109874516-8042af00-7c6f-11eb-8afc-65ef52448c7a.png)

A **work-in-progress** Magit clone for Neovim that is geared toward the Vim philosophy.

## Installation

| Plugin Manager                                       | Command                                                                        |
|------------------------------------------------------|--------------------------------------------------------------------------------|
| [Packer](https://github.com/wbthomason/packer.nvim)  | `use 'TimUntersberger/neogit'`                                                 |
| [Vim-plug](https://github.com/junegunn/vim-plug)     | `Plug 'TimUntersberger/neogit'`                                                |
| [NeoBundle](https://github.com/Shougo/neobundle.vim) | `NeoBundle 'TimUntersberger/neogit'`                                           |
| [Vundle](https://github.com/VundleVim/Vundle.vim)    | `Bundle 'TimUntersberger/neogit'`                                              |
| [Pathogen](https://github.com/tpope/vim-pathogen)    | `git clone https://github.com/TimUntersberger/neogit.git ~/.vim/bundle/neogit` |
| [Dein](https://github.com/Shougo/dein.vim)           | `call dein#add('TimUntersberger/neogit')`                                      |

You also use in the built-in package manager:
```bash
$ git clone --depth 1 https://github.com/TimUntersberger/neogit $XDG_CONFIG_HOME/nvim/pack/plugins/start/neogit
```

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
| L            | Open log popup                                   |
| p            | Open pull popup                                  |
| P            | Open push popup                                  |
| Z            | Open stash popup                                 |
| ?            | Open help popup                                  |
| x            | Discard changes (also supports discarding hunks) |
| \<C-r>       | Refresh Buffer                                   |
| \<C-C>\<C-C> | Commit (when writing a commit message)           |

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

## Testing

Assure that you have [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) 
installed as a plugin for your neovim instance. Afterwards, run `make test`
to run the unit test suite.

Plenary uses it's own port of busted and a bundled luassert, so consult their
code and the respective [busted](http://olivinelabs.com/busted/) and 
[luassert](http://olivinelabs.com/busted/#asserts) docs for what methods are 
available.
