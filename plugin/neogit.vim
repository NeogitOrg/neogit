lua require("neogit.status")

function! s:refresh()
  if match(bufname(), "^\\(Neogit.*\\|.git/COMMIT_EDITMSG\\)$") == 0
    return
  endif
  lua vim.defer_fn(function() __NeogitStatusRefresh() end, 0)
endfunction

call s:refresh()

augroup Neogit
  au!
  au BufWritePost * call <SID>refresh()
augroup END

command! -nargs=0 Neogit :lua require'neogit.status'.create()<CR>
