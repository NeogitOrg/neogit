" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

au BufWipeout <buffer> lua require 'neogit.status'.close(true)

if !luaeval("require'neogit.config'.values.disable_context_highlighting")
  augroup NeogitStatusHighlightUpdater
  autocmd CursorMoved NeogitStatus :lua require'neogit.status'.update_highlight()
  augroup END
endif
