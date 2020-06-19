lua neogit = require("neogit")

function! s:neogit_toggle()
endfunction

function! s:neogit_move_to_section(step)
  let line = line('.')
  let i = 0
  let idx = -1

  for location in s:state.locations
    if location.start <= line && line <= location.end
      let idx = i
      break
    endif
    let i = i + 1
  endfor

  if i == len(s:state.locations)
    if a:step < 0
      let idx = i
    endif
  endif

  if len(s:state.locations) - 1 >= idx + a:step && idx + a:step >= 0
    call cursor(s:state.locations[idx + a:step].start, 0)
  endif
endfunction

function s:neogit_next_section()
  call s:neogit_move_to_section(1)
endfunction

function s:neogit_prev_section()
  call s:neogit_move_to_section(-1)
endfunction

function! s:neogit_stage_all()
  call system("git add " . join(map(s:state.status.unstaged_changes, {_, val -> val.file}), " "))
  call s:neogit_refresh_status()
endfunction

function! s:neogit_unstage_all()
  call system("git reset")
  call s:neogit_refresh_status()
endfunction

function! s:neogit_stage()
  let line = getline('.')
  let matches = matchlist(line, "^modified \\(.*\\)$")

  if len(matches) != 0
    let file = matches[1]
    call system("git add " . file)
    call s:neogit_refresh_status()
  endif
endfunction

function! s:neogit_unstage()
  let line = getline('.')
  let matches = matchlist(line, "^modified \\(.*\\)$")

  if len(matches) != 0
    let file = matches[1]
    call system("git reset " . file)
    call s:neogit_refresh_status()
  endif
endfunction

function! s:neogit_refresh_status()
  setlocal modifiable

  let line = line('.')
  let col = col('.')

  call feedkeys('gg', 'x')
  call feedkeys('dG', 'x')
  call s:neogit_print_status()

  call cursor([line, col])
endfunction

function! s:neogit_print_status()
  setlocal modifiable

  let status = luaeval("neogit.status()")
  let stashes = luaeval("neogit.stashes()")
  let s:lineidx = 0

  let s:state = {
        \ "status": status,
        \ "stashes": stashes,
        \ "locations": []
        \}

  function! Write(str)
    call append(s:lineidx, a:str)
    let s:lineidx = s:lineidx + 1
  endfunction

  call Write("Head: " . status.branch)
  call Write("Push: " . status.remote)

  if len(status.unstaged_changes) != 0
    call Write("")
    call Write("Unstaged changes (" . len(status.unstaged_changes) . ")")
    let start = s:lineidx
    for change in status.unstaged_changes
      call Write(change.type . " " . change.file)
    endfor
    let end = s:lineidx
    call add(s:state.locations, {
          \ "name": "unstaged_changes",
          \ "start": start,
          \ "end": end
          \})
  endif

  if len(status.staged_changes) != 0
    call Write("")
    call Write("Staged changes (" . len(status.staged_changes) . ")")
    let start = s:lineidx
    for change in status.staged_changes
      call Write(change.type . " " . change.file)
    endfor
    let end = s:lineidx
    call add(s:state.locations, {
          \ "name": "staged_changes",
          \ "start": start,
          \ "end": end
          \})
  endif

  if len(stashes) != 0
    call Write("")
    call Write("Stashes (" . len(stashes) . ")")
    let start = l:lineidx
    for stash in stashes
      call Write("stash@{" . stash.idx . "} " . stash.name)
    endfor
    let end = s:lineidx
    call add(s:state.locations, {
          \ "name": "stashes",
          \ "start": start,
          \ "end": end
          \})
  endif

  if status.behind_by != 0
    call Write("")
    call Write("Unpulled from " . status.remote . " (" . status.behind_by . ")")
    let start = s:lineidx

    let commits = luaeval("neogit.unpulled('" . status.remote . "')")

    for commit in commits
      call Write(commit)
    endfor
    let end = s:lineidx
    call add(s:state.locations, {
          \ "name": "unpulled",
          \ "start": start,
          \ "end": end
          \})
  endif

  if status.ahead_by != 0
    call Write("")
    call Write("Unmerged into " . status.remote . " (" . status.ahead_by . ")")
    let start = s:lineidx
    let commits = luaeval("neogit.unmerged('" . status.remote . "')")

    for commit in commits
      call Write(commit)
    endfor
    let end = s:lineidx
    call add(s:state.locations, {
          \ "name": "unmerged",
          \ "start": start,
          \ "end": end
          \})
  endif
endfunction

function! s:neogit()
  enew

  call s:neogit_print_status()

  setlocal nomodifiable
  setlocal nohidden
  setlocal noswapfile
  setlocal nobuflisted

  nnoremap <buffer> <silent> q :bp!\|bd!#<CR>
  nnoremap <buffer> <silent> s :call <SID>neogit_stage()<CR>
  nnoremap <buffer> <silent> S :call <SID>neogit_stage_all()<CR>
  nnoremap <buffer> <silent> ]s :call <SID>neogit_next_section()<CR>
  nnoremap <buffer> <silent> [s :call <SID>neogit_prev_section()<CR>
  nnoremap <buffer> <silent> u :call <SID>neogit_unstage()<CR>
  nnoremap <buffer> <silent> U :call <SID>neogit_unstage_all()<CR>
  nnoremap <buffer> <silent> <TAB> :call <SID>neogit_toggle()<CR>
endfunction

command! -nargs=0 Neogit call <SID>neogit()

Neogit
