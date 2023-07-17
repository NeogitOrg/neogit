## Status Buffer
### NeogitBranch
Used in the header of the status buffer to label the current checked out branch

### NeogitRemote
Used in the header of the status buffer to label the current checked out branches' remote, if set

### NeogitUnmergedInto

### NeogitUnpulledFrom

### NeogitObjectId
Applied to the object SHA hash on the status buffer

### NeogitStash
Applied to a stashes name on the status buffer

### NeogitFold
Folded text highlight

## Status Buffer item's git status
### NeogitChangeModified
### NeogitChangeAdded
### NeogitChangeDeleted
### NeogitChangeRenamed
### NeogitChangeUpdated
### NeogitChangeCopied
### NeogitChangeBothModified
### NeogitChangeNewFile

## Status Buffer Section header
### NeogitUntrackedfiles
### NeogitUnstagedchanges
### NeogitUnmergedchanges
### NeogitUnpulledchanges
### NeogitRecentcommits
### NeogitStagedchanges
### NeogitStashes
### NeogitRebasing

## Signs - Line Highlights
### NeogitHunkHeader
### NeogitHunkHeaderHighlight
### NeogitDiffContext
### NeogitDiffContextHighlight
### NeogitDiffAdd
### NeogitDiffAddHighlight
### NeogitDiffDelete
### NeogitDiffDeleteHighlight
### NeogitDiffHeader
### NeogitDiffHeaderHighlight

### NeogitRebaseDone
Current position marker in rebase todo

### NeogitCursorLine


## Commit Buffer
### NeogitFilePath
Filepath for the file changed.

### NeogitCommitViewHeader
Used at the top of the commit view

## Log View Buffer
### NeogitGraph* & NeogitGraphBold*
Used when the `--colors` flag is enabled. The ANSI colors git provides get parsed and we use these highlight groups to re-color the graph as accurately as possible.

## Popups
### NeogitPopupSectionTitle
Applied to the section headers on all popups

### NeogitPopupBranchName
Applied to the current branch name on popups for emphasis

### NeogitPopupBold
Applied on "@{upstream}" and "pushRemote" for emphasis (but less emphasis that the branch name)

### NeogitPopup{Switch,Options,Config,Action}Key
Applied to the single-letter label that will trigger the function

### NeogitPopup{Switch,Options,Config,Action}Disabled
Applied to unimplemented actions, disabled flags, and unset values

### NeogitPopup{Switch,Options,Config}Enabled
Applied to set/enabled flags and values

## Notifications
### NeogitNotification{Info,Warning,Error}
Used by builtin notifications. By default linked to Diagnostic{Info,Warn,Error}

## Command History View
### NeogitCommandText
Applied to the CLI command run

### NeogitCommandTime
Applied to the timestamp for how long a command ran

### NeogitCommandCodeNormal
Applied to a successful command's exit status (zero).

### NeogitCommandCodeError
Applied to non-zero exit status codes.
