## Status
* change: pre load all diffs in a batch command (done)
* fix: improve status load time (done)
* feat: changing fold level with 1,2,3,4 (done)
* feat: contextually retain cursor position
* fix: improve stage/unstage all speed
* feat: stage hunk
* feat: unstage hunk
* feat: stage selection
* feat: unstage selection
* feat: git restore

## Push

* change: maybe only send a notification on completion?

## Popups

* chore: rename popup -> transient
* fix: default values for options don't get displayed on initial draw

## Buffer

* feat: add the concept of a buffer "object"
* change: create function now returns a buffer "object"
* refactor: automatically create a mappings_manager when creating a buffer and pass it as second argument to the initialize function

## Highlighting

* refactor: extract highlighting logic into syntax files
