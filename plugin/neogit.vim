lua neogit = require("neogit")

function! s:neogit()
  let status = luaeval("neogit.status()")
  let s:lineidx = 0

  echo status

  enew

  function! Write(str)
    call append(s:lineidx, a:str)
    let s:lineidx = s:lineidx + 1
  endfunction

  call Write("Head: " . status.branch)
  call Write("Push: " . status.remote)

  if len(status.unstaged_changes) != 0
    call Write("")
    call Write("Unstaged changes (" . len(status.unstaged_changes) . ")")
    for change in status.unstaged_changes
      call Write(change.type . " " . change.file)
    endfor
  endif

  if len(status.staged_changes) != 0
    call Write("")
    call Write("Staged changes (" . len(status.staged_changes) . ")")
    for change in status.staged_changes
      call Write(change.type . " " . change.file)
    endfor
  endif

  if status.behind_by != 0
    call Write("")
    call Write("Unpulled from " . status.remote . " (" . status.behind_by . ")")

    let commits = luaeval("neogit.unpulled('" . status.remote . "')")

    for commit in commits
      call Write(commit)
    endfor
  endif

  if status.ahead_by != 0
    call Write("")
    call Write("Unmerged into " . status.remote . " (" . status.ahead_by . ")")

    let commits = luaeval("neogit.unmerged('" . status.remote . "')")

    for commit in commits
      call Write(commit)
    endfor
  endif

  setlocal nomodifiable
  setlocal nohidden
  setlocal noswapfile
  setlocal nobuflisted

  nnoremap <buffer> <silent> q :bd!<CR>
endfunction

command! -nargs=0 Neogit call <SID>neogit()

Neogit
