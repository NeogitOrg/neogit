if exists('g:neovim_loaded')
  finish
endif
let g:neovim_loaded = 1

if !luaeval("require 'neogit.bootstrap'")
  finish
endif

function! neogit#refresh_manually(file)
  call luaeval('(function() require "neogit.status".refresh_manually(_A) end)()', a:file)
endfunction

function! s:refresh(file)
  if match(bufname(), "^\\(Neogit.*\\|.git/COMMIT_EDITMSG\\)$") == 0
    return
  endif
  call luaeval('(function() require "neogit.status".refresh_viml_compat(_A) end)()', a:file)
endfunction

augroup Neogit
  au!
  au BufWritePost,BufEnter,FocusGained,ShellCmdPost,VimResume * call <SID>refresh(expand('<afile>'))
  au DirChanged * lua vim.defer_fn(function() require 'neogit.status'.dispatch_reset() end, 0)
  au ColorScheme * lua require'neogit.lib.hl'.setup()
augroup END

command! -nargs=* Neogit lua require'neogit'.open(require'neogit.lib.util'.parse_command_args(<f-args>))<CR>
