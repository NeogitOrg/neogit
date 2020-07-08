if exists("b:current_syntax")
  finish
endif

" syn sync fromstart

syn match neogitTitleCount /([0-9])\+/ contained
syn match neogitBranch /[a-zA-Z]\+/ contained
syn match neogitTitle /^\(.*\(\W[a-zA-Z]*\/\)\@=\|\([a-zA-Z]\W\?\)*\)/ contained nextgroup=neogitRemoteIdentifier,neogitTitleCount skipwhite
syn match neogitRemoteIdentifier /[a-zA-Z]\+\/[a-zA-Z]\+/ contained

syn region neogitRemoteHead start=/^Head:\zs/ end=/$/ contains=neogitBranch
syn region neogitRemotePush start=/^Push:\zs/ end=/$/ contains=neogitRemoteIdentifier
syn region neogitUnstaged start=/^Unstaged changes ([0-9]\+)$/ end=/$/ contains=neogitTitle,neogitTitleCount
syn region neogitUntracked start=/^Untracked files ([0-9]\+)$/ end=/$/ contains=neogitTitle,neogitTitleCount
syn region neogitStaged start=/^Staged changes ([0-9]\+)$/ end=/$/ contains=neogitTitle,neogitTitleCount transparent
syn region neogitUnmergedTitle start=/^Unmerged into/ end=/$/ contains=neogitTitle,neogitTitleCount,neogitRemoteIdentifier

hi def link neogitBranch Macro
hi def link neogitTitle Function
hi def link neogitRemoteIdentifier SpecialChar
