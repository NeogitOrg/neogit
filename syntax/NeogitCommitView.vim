if exists("b:current_syntax")
  finish
endif

syn match NeogitDiffAdd /.*/ contained
syn match NeogitDiffDelete /.*/ contained

let b:current_syntax = 1
