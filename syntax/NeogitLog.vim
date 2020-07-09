if exists("b:current_syntax")
  finish
endif

syn match neogitHash /[0-9a-z]\{7}/ contained

syn region neogitLog start=/^[\*|\\ ]*[0-9a-z]\{7}/ end=/./ contains=neogitHash transparent

hi def link neogitHash Comment
