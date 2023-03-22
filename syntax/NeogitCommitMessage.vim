if (exists("b:current_syntax"))
  finish
endif

source $VIMRUNTIME/syntax/gitcommit.vim

let b:current_syntax = 1
