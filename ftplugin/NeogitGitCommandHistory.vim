" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

function! NeogitFoldFunction()
  return getline(v:foldstart)
endfunction

setlocal foldmethod=manual
setlocal foldlevel=1
setlocal fillchars=fold:\ 
setlocal foldminlines=0
setlocal foldtext=NeogitFoldFunction()
