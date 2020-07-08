lua neogit = require("neogit")

let s:change_regex = "^\\(modified\\|new file\\|deleted\\)\\? \\(\\S*\\)$"
let s:untracked_regex = "^\\(\\S*\\)$"
let s:previous_shell_output = []
let s:previous_shell_cmd = ""
let g:neogit_use_tab = 1

function! s:neogit_execute_shell(cmd, msg)
  echo a:msg . "..."
  let s:previous_shell_cmd = a:cmd
  let s:previous_shell_output = systemlist(a:cmd)
endfunction

function! s:neogit_get_hovered_file()
  let line = getline('.')
  let matches = matchlist(line, s:change_regex)
  let idx = 2

  if len(matches) == 0
    let matches = matchlist(line, s:untracked_regex)
    let idx = 1
  endif

  if len(matches) == 0
    return v:null
  endif

  return matches[idx]
endfunction

function! s:neogit_get_hovered_change()
  let section = s:neogit_get_hovered_section()
  let changes = s:state.status[section.name]
  let line = line('.')
  let change = v:null

  for curr_change in changes
    if curr_change.start <= line && line <= curr_change.end
      let change = curr_change
      break
    endif
  endfor

  return change
endfunction

function! s:neogit_toggle()
  if len(matchlist(getline('.'), s:change_regex)) == 0
    return
  endif

  setlocal modifiable

  let section = s:neogit_get_hovered_section()

  if section is v:null
    return
  endif

  let changes = s:state.status[section.name]
  let line = line('.')

  let change = s:neogit_get_hovered_change()

  if change.type == "deleted" || change.type == "new file"
    return
  endif

  if change.diff_open == v:true 
    let change.diff_open = v:false

    silent execute ':' . (change.start + 1)
    silent execute 'normal ' . change.diff_height . 'dd'
    normal k

    for c in changes
      if c.start > change.start 
        let c.start = c.start - change.diff_height
        let c.end = c.end - change.diff_height
      endif
    endfor

    let change.end = change.start
    let section.end = section.end - change.diff_height
    let change.diff_height = 0
  else
    let result = systemlist("git diff " . change.file)
    let diff = result[4:-1]

    let change.diff_open = v:true
    let change.diff_height = len(diff) 

    echo change

    for c in changes
      if c.start > change.start 
        let c.start = c.start + change.diff_height
        let c.end = c.end + change.diff_height
      endif
    endfor

    let change.end = change.start + change.diff_height
    let section.end = section.end + change.diff_height

    call append('.', diff)
  endif

  setlocal nomodifiable
endfunction

function! s:neogit_get_hovered_section_idx()
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

  return idx
endfunction

function! s:neogit_get_hovered_section()
  return s:state.locations[s:neogit_get_hovered_section_idx()]
endfunction

function! s:neogit_move_to_section(step)
  let idx = s:neogit_get_hovered_section_idx()

  if a:step < 0 && idx == -1 
    let idx = 0
  endif

  if len(s:state.locations) == idx + a:step
    let idx = -1
  endif

  call cursor(s:state.locations[idx + a:step].start, 0)
endfunction

function! s:neogit_move_to_item(step)
  let section = s:neogit_get_hovered_section()
  let changes = s:state.status[section.name]
  let file = s:neogit_get_hovered_file()
  let line = line('.')

  let change = s:neogit_get_hovered_change()

  let next_line = 0

  if a:step > 0 
    let next_line = change.start + change.diff_height + 1
  else
    for c in changes
      if c.end == change.start - 1
        let next_line = c.start
        break
      endif
    endfor
  endif

  if change isnot v:null && next_line <= section.end && next_line >= section.start + 1
    silent execute ':' . next_line
  endif
endfunction

function! s:neogit_next_item()
  call s:neogit_move_to_item(1)
endfunction

function! s:neogit_prev_item()
  call s:neogit_move_to_item(-1)
endfunction

function! s:neogit_next_section()
  call s:neogit_move_to_section(1)
endfunction

function! s:neogit_prev_section()
  call s:neogit_move_to_section(-1)
endfunction

function! s:neogit_stage_all()
  call s:neogit_execute_shell("git add .", "")
  call s:neogit_refresh_status()
endfunction

function! s:neogit_unstage_all()
  call s:neogit_execute_shell("git reset", "")
  call s:neogit_refresh_status()
endfunction

function! s:neogit_stage()
  let file = s:neogit_get_hovered_file()

  if file != v:null
    call s:neogit_execute_shell("git add " . file, "")
    call s:neogit_refresh_status()
  endif
endfunction

function! s:neogit_unstage()
  let file = s:neogit_get_hovered_file()

  if file != v:null
    call s:neogit_execute_shell("git reset " . file, "")
    call s:neogit_refresh_status()
  endif
endfunction

function! s:neogit_focus()
  silent execute ':sb ' . bufnr('Neogit')
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

  if len(status.untracked_files) != 0
    call Write("")
    call Write("Untracked files (" . len(status.untracked_files) . ")")
    let start = s:lineidx
    for file in status.untracked_files
      call Write(file.name)
      let file.start = s:lineidx
      let file.end = s:lineidx
    endfor
    let end = s:lineidx
    call add(s:state.locations, {
          \ "name": "untracked_files",
          \ "start": start,
          \ "end": end
          \})
  endif

  if len(status.unstaged_changes) != 0
    call Write("")
    call Write("Unstaged changes (" . len(status.unstaged_changes) . ")")
    let start = s:lineidx
    for change in status.unstaged_changes
      call Write(change.type . " " . change.file)
      let change.start = s:lineidx
      let change.end = s:lineidx
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
      let change.start = s:lineidx
      let change.end = s:lineidx
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

function! s:neogit_fetch(remote)
  call s:neogit_execute_shell('git fetch ' . a:remote, "Fetching")
  call s:neogit_refresh_status()
endfunction

function! s:neogit_pull(remote)
  call s:neogit_execute_shell('git pull ' . a:remote, "Pulling")
  call s:neogit_refresh_status()
endfunction

function! s:neogit_push(remote)
  call s:neogit_execute_shell('git push' . a:remote, "Pushing")
  call s:neogit_refresh_status()
endfunction

function! s:neogit_commit_on_delete()
  let msg = getline(0, '$')

  silent !rm .git/COMMIT_EDITMSG

  if len(msg) > 0
    call s:neogit_execute_shell('git commit -m "' . join(msg, "\r\n") . '"', "Commiting")
  endif

endfunction

function! s:neogit_commit()
  silent !rm .git/COMMIT_EDITMSG
  silent execute 'above 15sp .git/COMMIT_EDITMSG'

  setlocal nohidden
  setlocal noswapfile
  setlocal nobuflisted

  autocmd! WinClosed <buffer> call <SID>neogit_commit_on_delete()
endfunction

function! s:neogit_log()
  below 15new

  setlocal noswapfile
  setlocal nobuflisted
  setlocal nohidden

  let result = luaeval("neogit.log()")

  call append(0, result)
  
  normal gg

  setlocal nomodifiable
  setlocal readonly

  file NeogitLog

  nnoremap <buffer> <silent> q :close!<CR>
endfunction

function! s:neogit_quit()
  if g:neogit_use_tab == 1
    bd!
  else
    bp!\|bd!#
  endif
endfunction

function! s:neogit_show_previous_shell_output()
  if len(s:previous_shell_output) == 0
    echo "Empty shell output"
    return
  endif

  below 15new

  call setline(1, '$ ' . s:previous_shell_cmd)
  call append(1, '')
  call append('.', s:previous_shell_output)

  setlocal readonly
  setlocal nomodifiable
  setlocal noswapfile
  setlocal nohidden
  setlocal nobuflisted

  file NeogitShellOutput

  nnoremap <buffer> <silent> q :close!<CR>
endfunction

function! s:neogit()
  if g:neogit_use_tab == 1 
    tabnew
  else 
    enew
  endif

  call s:neogit_print_status()

  file NeogitStatus
  set filetype=NeogitStatus

  setlocal readonly
  setlocal nomodifiable
  setlocal noswapfile
  setlocal nohidden
  setlocal nobuflisted

  autocmd! BufEnter <buffer> call <SID>neogit_refresh_status()

  "{{{ fetch
  nnoremap <buffer> <silent> fp :call <SID>neogit_fetch("")<CR>
  nnoremap <buffer> <silent> fu :call <SID>neogit_fetch("upstream")<CR>
  "}}}
  "{{{ pull
  nnoremap <buffer> <silent> Fp :call <SID>neogit_pull("")<CR>
  nnoremap <buffer> <silent> Fu :call <SID>neogit_pull("upstream")<CR>
  "}}}
  "{{{ push 
  nnoremap <buffer> <silent> Pp :call <SID>neogit_push("")<CR>
  nnoremap <buffer> <silent> Pu :call <SID>neogit_push("upstream")<CR>
  "}}}
  "{{{ commit
  nnoremap <buffer> <silent> cc :call <SID>neogit_commit()<CR>
  "}}}
  "{{{ refresh
  nnoremap <buffer> <silent> r :call <SID>neogit_refresh_status()<CR>
  "}}}
  "{{{ stage
  nnoremap <buffer> <silent> s :call <SID>neogit_stage()<CR>
  nnoremap <buffer> <silent> S :call <SID>neogit_stage_all()<CR>
  "}}}
  "{{{ unstage
  nnoremap <buffer> <silent> u :call <SID>neogit_unstage()<CR>
  nnoremap <buffer> <silent> U :call <SID>neogit_unstage_all()<CR>
  "}}}
  "{{{ movement
  nnoremap <buffer> <silent> <c-j> :call <SID>neogit_next_section()<CR>
  nnoremap <buffer> <silent> <c-k> :call <SID>neogit_prev_section()<CR>
  nnoremap <buffer> <silent> <s-j> :call <SID>neogit_next_item()<CR>
  nnoremap <buffer> <silent> <s-k> :call <SID>neogit_prev_item()<CR>
  "}}}
  "{{{ log
  nnoremap <buffer> <silent> l :call <SID>neogit_log()<CR>
  "}}}
  "{{{ misc
  nnoremap <buffer> <silent> q :call <SID>neogit_quit()<CR>
  nnoremap <buffer> <silent> $ :call <SID>neogit_show_previous_shell_output()<CR>
  nnoremap <buffer> <silent> <TAB> :call <SID>neogit_toggle()<CR>
  "}}}
endfunction

command! -nargs=0 Neogit call <SID>neogit()
