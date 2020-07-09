if exists("b:current_syntax")
  finish
endif

syn match neogitBranch /[a-zA-Z]\+/ contained
syn match neogitTitle /^\(.*\(\W[a-zA-Z]*\/\)\@=\|\([a-zA-Z]\W\?\)*\)/ contained
syn match neogitRemote /[a-zA-Z]\+\/[a-zA-Z]\+/ contained
syn match neogitHash /[0-9a-z]\{7}/ contained

syn match neogitChangeModified /^modified\ze.*$/ contained
syn match neogitChangeDeleted /^deleted\ze.*$/ contained
syn match neogitChangeNewFile /^new file\ze.*$/ contained

syn match neogitDiffAdd /^+.*$/ contained
syn match neogitDiffDelete /^-.*$/ contained

syn region neogitRemoteHead start=/^Head:\zs/ end=/$/ contains=neogitBranch
syn region neogitRemotePush start=/^Push:\zs/ end=/$/ contains=neogitRemote

syn region neogitUnstaged start=/^Unstaged changes ([0-9]\+)$/ end=/$/ contains=neogitTitle
syn region neogitUntracked start=/^Untracked files ([0-9]\+)$/ end=/$/ contains=neogitTitle
syn region neogitStaged start=/^Staged changes ([0-9]\+)$/ end=/$/ contains=neogitTitle transparent
syn region neogitUnmergedTitle start=/^Unmerged into/ end=/$/ contains=neogitTitle,neogitRemote

syn region neogitChange start=/^\(modified\|deleted\|new file\) .*$/ end=/$/ contains=neogitChangeModified,neogitChangeDeleted,neogitChangeNewFile
syn region neogitHunk start=/^@@ -\d\+,\d\+ +\d\+,\d\+ @@/ end=/^@@ -\d\+,\d\+ +\d\+,\d\+ @@/ contains=neogitDiffAdd,neogitDiffDelete transparent
syn region neogitLog start=/^[0-9a-z]\{7} / end=/./ contains=neogitHash

hi def link neogitBranch Macro
hi def link neogitTitle Function
hi def link neogitRemote SpecialChar
hi def link neogitHash Comment

if g:neogit_highlight_modifier == 1 
  hi def link neogitChangeNewFile DiffAdd
  hi def link neogitChangeDeleted DiffDelete
  hi def link neogitChangeModified DiffChange
endif

hi def link neogitDiffAdd DiffAdd
hi def link neogitDiffDelete DiffDelete

