if (exists("b:did_ftplugin"))
  finish
endif

source $VIMRUNTIME/ftplugin/gitcommit.vim

let b:did_ftplugin = 1
