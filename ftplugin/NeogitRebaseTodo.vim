if (exists("b:did_ftplugin"))
  finish
endif

source $VIMRUNTIME/ftplugin/gitrebase.vim

let b:did_ftplugin = 1
