if exists("b:current_syntax")
  finish
endif

syn match neogitBranch /[a-zA-Z]\+/ contained
syn match neogitTitle /^\(.*\(\W[a-zA-Z]*\/\)\@=\|\([a-zA-Z]\W\?\)*\)/ contained
syn match neogitRemoteIdentifier /[a-zA-Z]\+\/[a-zA-Z]\+/ contained
syn match neogitChangeModified /^modified\ze.*$/ contained
syn match neogitChangeDeleted /^deleted\ze.*$/ contained
syn match neogitChangeNewFile /^new file\ze.*$/ contained
syn match neogitDiffAdd /^+.*$/ contained
syn match neogitDiffDelete /^-.*$/ contained

syn region neogitRemoteHead start=/^Head:\zs/ end=/$/ contains=neogitBranch
syn region neogitRemotePush start=/^Push:\zs/ end=/$/ contains=neogitRemoteIdentifier
syn region neogitUnstaged start=/^Unstaged changes ([0-9]\+)$/ end=/$/ contains=neogitTitle
syn region neogitUntracked start=/^Untracked files ([0-9]\+)$/ end=/$/ contains=neogitTitle
syn region neogitStaged start=/^Staged changes ([0-9]\+)$/ end=/$/ contains=neogitTitle transparent
syn region neogitUnmergedTitle start=/^Unmerged into/ end=/$/ contains=neogitTitle,neogitRemoteIdentifier
syn region neogitChange start=/^\(modified\|deleted\|new file\) .*$/ end=/$/ contains=neogitChangeModified,neogitChangeDeleted,neogitChangeNewFile
syn region neogitHunk start=/^@@ -\d\+,\d\+ +\d\+,\d\+ @@/ end=/^@@ -\d\+,\d\+ +\d\+,\d\+ @@/ contains=neogitDiffAdd,neogitDiffDelete transparent

hi def link neogitChangeModified diffChanged
hi def link neogitChangeDeleted diffRemoved
hi def link neogitChangeNewFile diffAdded
hi def link neogitDiffAdd diffAdded
hi def link neogitDiffDelete diffRemoved
hi def link neogitBranch Macro
hi def link neogitTitle Function
hi def link neogitRemoteIdentifier SpecialChar
