if exists("b:current_syntax")
  finish
endif

syn match NeogitDiffAdd /.*/ contained
syn match NeogitDiffDelete /.*/ contained

hi def link NeogitDiffAdd DiffAdd
hi def link NeogitDiffDelete DiffDelete

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
