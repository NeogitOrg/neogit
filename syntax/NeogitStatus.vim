if exists("b:current_syntax")
  finish
endif

" Support the rebase todo highlights
source $VIMRUNTIME/syntax/gitrebase.vim

" Added for Reverting section when sequencer/todo doesn't exist
syn match gitrebasePick       "\v^work=>"           nextgroup=gitrebaseCommit skipwhite
syn match gitrebaseBreak      "\v^onto=>"           nextgroup=gitrebaseCommit skipwhite

" Labels to the left of files
syn match NeogitChangeModified     /\v^Modified( by us|)/
syn match NeogitChangeAdded        /\v^Added( by us|)/
syn match NeogitChangeDeleted      /\v^Deleted( by us|)/
syn match NeogitChangeRenamed      /\v^Renamed( by us|)/
syn match NeogitChangeUpdated      /\v^Updated( by us|)/
syn match NeogitChangeCopied       /\v^Copied( by us|)/
syn match NeogitChangeBothModified /^Both Modified/
syn match NeogitChangeNewFile      /^New file/

syn match NeogitCommitMessage /.*/                  contained
syn match NeogitBranch        /\S\+/                contained nextgroup=NeogitObjectId,NeogitCommitMessage
syn match NeogitRemote        /\S\+/                contained nextgroup=NeogitObjectId,NeogitCommitMessage
syn match NeogitDiffAdd       /.*/                  contained
syn match NeogitDiffDelete    /.*/                  contained
syn match NeogitUnmergedInto  /Unmerged into/       contained
syn match NeogitUnpushedTo    /Unpushed to/         contained
syn match NeogitUnpulledFrom  /Unpulled from/       contained
syn match NeogitTagName       /\S\+ /               contained nextgroup=NeogitTagDistance
syn match NeogitTagDistance   /[0-9]/               contained

syn match NeogitStash         /stash@{[0-9]*}\ze/
syn match NeogitObjectId      "\v<\x{7,}>"          contains=@NoSpell

let b:sections = [
      \ "Untracked files",
      \ "Unstaged changes",
      \ "Unmerged changes",
      \ "Unpulled changes",
      \ "Recent commits",
      \ "Staged changes",
      \ "Stashes",
      \ "Rebasing",
      \ "Reverting",
      \ "Picking"
      \ ]

for section in b:sections
  let id = join(split(section, " "), "")
  execute 'syn match Neogit' . id . ' /^' . section . '/ contained'
  execute 'syn region Neogit' . id . 'Region start=/^' . section . '\ze.*/ end=/./ contains=Neogit' . id
endfor

syn region NeogitHeadRegion         start=/^Head: \zs/        end=/$/ contains=NeogitObjectId,NeogitBranch
syn region NeogitPushRegion         start=/^Push: \zs/        end=/$/ contains=NeogitObjectId,NeogitRemote
syn region NeogitMergeRegion        start=/^Merge: \zs/       end=/$/ contains=NeogitObjectId,NeogitRemote
syn region NeogitUnmergedIntoRegion start=/^Unmerged into .*/ end=/$/ contains=NeogitRemote,NeogitUnmergedInto
syn region NeogitUnpushedToRegion   start=/^Unpushed to .*/   end=/$/ contains=NeogitRemote,NeogitUnpushedTo
syn region NeogitUnpulledFromRegion start=/^Unpulled from .*/ end=/$/ contains=NeogitRemote,NeogitUnpulledFrom
syn region NeogitDiffAddRegion      start=/^+.*$/             end=/$/ contains=NeogitDiffAdd
syn region NeogitDiffDeleteRegion   start=/^-.*$/             end=/$/ contains=NeogitDiffDelete
syn region NeogitTagRegion          start=/^Tag: \zs/         end=/$/ contains=NeogitTagName,NeogitTagDistance

let b:current_syntax = 1
