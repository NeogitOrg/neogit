lua require("neogit")
lua require("neogit.status")

function! s:refresh()
  if match(bufname(), "^\\(Neogit.*\\|.git/COMMIT_EDITMSG\\)$") == 0
    return
  endif
  lua vim.defer_fn(function() require 'neogit.status'.refresh() end, 0)
endfunction

call s:refresh()

augroup Neogit
  au!
  au BufWritePost,BufEnter,FocusGained,ShellCmdPost,VimResume * call <SID>refresh()
  au DirChanged * lua vim.defer_fn(function() require 'neogit.status'.reset() end, 0)
augroup END

command! -nargs=* Neogit lua require'neogit'.open(require'neogit.lib.util'.parse_command_args(<f-args>))<CR>
