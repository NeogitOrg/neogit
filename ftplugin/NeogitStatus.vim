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
setlocal foldminlines=0
setlocal foldtext=NeogitFoldFunction()

au BufWipeout <buffer> lua require 'neogit.status'.close()

if !luaeval("require'neogit.config'.values.disable_context_highlighting")
  augroup NeogitStatusHighlightUpdater
  autocmd CursorMoved NeogitStatus :lua require'neogit.status'.update_highlight()
  augroup END
endif
