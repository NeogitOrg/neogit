## General

* refactor: extract buffers like "NeogitLog" into their own files

## Commit

* feat: save commit messages in memory
* feat: make it possible to go through previous commit messages when writing one

## Status

* feat: contextually retain cursor position (WIP)
* feat: git restore
* feat: $ to see git command history
* fix: unstage/stage all don't check for existing entries

## Push

## Popups

* chore: rename popup -> transient
* fix: default values for options don't get displayed on initial draw

## Stash

* feat: delete stash

## Buffer

* refactor: move buffer into lib
* feat: add the concept of a buffer "object"
* change: create function now returns a buffer "object"
* refactor: automatically create a mappings_manager when creating a buffer and pass it as second argument to the initialize function

## Highlighting
