if exists("b:current_syntax")
  finish
endif

syn match NeogitDiffAdd /.*/ contained
syn match NeogitDiffDelete /.*/ contained

hi def link NeogitDiffAdd DiffAdd
hi def link NeogitDiffDelete DiffDelete

hi def NeogitDiffAddHighlight guibg=#404040 guifg=#859900
hi def NeogitDiffDeleteHighlight guibg=#404040 guifg=#dc322f
hi def NeogitDiffContextHighlight guibg=#333333 guifg=#b2b2b2
hi def NeogitHunkHeader guifg=#cccccc guibg=#404040
hi def NeogitHunkHeaderHighlight guifg=#cccccc guibg=#4d4d4d
hi def NeogitFilePath guifg=#798bf2

hi def NeogitCommitViewHeader guifg=#ffffff guibg=#94bbd1

sign define NeogitHunkHeader linehl=NeogitHunkHeader
sign define NeogitHunkHeaderHighlight linehl=NeogitHunkHeaderHighlight

sign define NeogitDiffContextHighlight linehl=NeogitDiffContextHighlight
sign define NeogitDiffAdd linehl=NeogitDiffAdd
sign define NeogitDiffAddHighlight linehl=NeogitDiffAddHighlight
sign define NeogitDiffDelete linehl=NeogitDiffDelete
sign define NeogitDiffDeleteHighlight linehl=NeogitDiffDeleteHighlight

sign define NeogitCommitViewHeader linehl=NeogitCommitViewHeader
sign define NeogitCommitViewDescription linehl=NeogitHunkHeader
