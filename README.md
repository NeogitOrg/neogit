# Neogit

A Magit clone for Neovim that may change some things to fit the Vim philosophy.

## Status

Very WIP.

## Todo

The todo file does not represent ALL of the missing features. This file just shows the features which I noticed were missing and I have to implement. This file will grow in the future.

[TODO](./todo.md)

## Commands

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
