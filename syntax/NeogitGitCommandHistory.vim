if exists("b:current_syntax")
  finish
endif

syn match NeogitCommandText /^.*$/
syn match NeogitCommandCodeError /^ [0-9]\{3}/ contained
syn match NeogitCommandCodeNormal /^  0/ contained

syn region NeogitCommandRegion start=/^[0-9 ]\{3}/ end=/$/ transparent contains=NeogitCommandCodeError,NeogitCommandCodeNormal

hi def link NeogitCommandText Comment
hi NeogitCommandCodeNormal guifg=#80ff95
hi NeogitCommandCodeError guifg=#c44323

hi Folded guifg=None guibg=None
