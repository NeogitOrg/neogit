if exists("b:current_syntax")
  finish
endif

" Support the rebase todo highlights
source $VIMRUNTIME/syntax/gitrebase.vim

syn match NeogitCommitMessage /.*/                contained
syn match NeogitBranch        /\S\+/              contained nextgroup=NeogitCommitMessage
syn match NeogitRemote        /\S\+/              contained nextgroup=NeogitCommitMessage
syn match NeogitDiffAdd       /.*/                contained
syn match NeogitDiffDelete    /.*/                contained
syn match NeogitUnmergedInto  /Unmerged into/     contained
syn match NeogitUnpulledFrom  /Unpulled from/     contained
syn match NeogitStash         /stash@{[0-9]*}\ze/
syn match NeogitObjectId      /^[a-z0-9]\{7,}\>\s/

let b:sections = ["Untracked files", "Unstaged changes", "Unmerged changes", "Unpulled changes", "Recent commits", "Staged changes", "Stashes", "Rebasing"]

for section in b:sections
  let id = join(split(section, " "), "")
  execute 'syn match Neogit' . id . ' /^' . section . '/ contained'
  execute 'syn region Neogit' . id . 'Region start=/^' . section . '\ze.*/ end=/./ contains=Neogit' . id
endfor

syn region NeogitHeadRegion         start=/^Head: \zs/        end=/$/ contains=NeogitBranch
syn region NeogitPushRegion         start=/^Push: \zs/        end=/$/ contains=NeogitRemote
syn region NeogitUnmergedIntoRegion start=/^Unmerged into .*/ end=/$/ contains=NeogitRemote,NeogitUnmergedInto
syn region NeogitUnpulledFromRegion start=/^Unpulled from .*/ end=/$/ contains=NeogitRemote,NeogitUnpulledFrom
syn region NeogitDiffAddRegion      start=/^+.*$/             end=/$/ contains=NeogitDiffAdd
syn region NeogitDiffDeleteRegion   start=/^-.*$/             end=/$/ contains=NeogitDiffDelete

let b:current_syntax = 1
