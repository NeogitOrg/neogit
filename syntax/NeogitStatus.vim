if exists("b:current_syntax")
  finish
endif

syn match Macro /^Head: \zs.*$/
syn match SpecialChar /^Push: \zs.*/
syn match Function /^Untracked files\ze (/
syn match Function /^Unstaged changes\ze (/
syn match Function /^Unmerged changes\ze (/
syn match Function /^Staged changes\ze (/
syn match Function /^Stashes\ze (/
syn match Function /^Unmerged into\ze .* (/
syn match SpecialChar /^Unmerged into \zs.*\ze (/
syn match Function /^Unpulled from\ze .* (/
syn match SpecialChar /^Unpulled from \zs.*\ze (/
syn match Comment /^[a-z0-9]\\{7}\ze /
syn match Comment /^stash@{[0-9]*}\ze /
syn match DiffAdd /^+.*/
syn match DiffDelete /^-.*/

"TODO: find a better way to do this
hi Folded guibg=None guifg=None
