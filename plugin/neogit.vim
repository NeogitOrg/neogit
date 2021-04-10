lua require("neogit")
lua require("neogit.status")

function! s:refresh(file)
  if match(bufname(), "^\\(Neogit.*\\|.git/COMMIT_EDITMSG\\)$") == 0
    return
  endif
  call luaeval('(function() require "neogit.status".dispatch_refresh({ status = true, diffs = {_A}}) end)()', a:file)
endfunction

lua require 'neogit.status'.dispatch_refresh(true)

augroup Neogit
  au!
  au BufWritePost,BufEnter,FocusGained,ShellCmdPost,VimResume * call <SID>refresh('*:' . expand('<afile>'))
  au DirChanged * lua vim.defer_fn(function() require 'neogit.status'.dispatch_reset() end, 0)
augroup END

command! -nargs=* Neogit lua require'neogit'.open(require'neogit.lib.util'.parse_command_args(<f-args>))<CR>
