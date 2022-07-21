if (exists("b:current_syntax"))
  finish
endif

source $VIMRUNTIME/syntax/gitrebase.vim

let b:current_syntax = 1
