# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Log Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("l") }

  # TODO: PTY needs to be bigger to show the entire popup
  let(:view) do
    [
      " Commit Limiting                                                                ",
      " -n Limit number of commits (--max-count=256)                                   ",
      " -A Limit to author (--author=)                                                 ",
      " -F Search messages (--grep=)                                                   ",
      " -G Search changes (-G)                                                         ",
      " -S Search occurrences (-S)                                                     ",
      " -L Trace line evolution (-L)                                                   ",
      " -s Limit to commits since (--since=)                                           ",
      " -u Limit to commits until (--until=)                                           ",
      " =m Omit merges (--no-merges)                                                   ",
      " =p First parent (--first-parent)                                               ",
      " -i Invert search messages (--invert-grep)                                      ",
      "                                                                                ",
      " History Simplification                                                         ",
      " -D Simplify by decoration (--simplify-by-decoration)                           ",
      " -- Limit to files (--)                                                         ",
      " -f Follow renames when showing single-file log (--follow)                      ",
      "                                                                                ",
      " Commit Ordering                                                                ",
      " -r Reverse order (--reverse)                                                   ",
      " -o Order commits by (--[topo|author-date|date]-order)                          ",
      " =R List reflog (--reflog)                                                      "
    ]
  end

  %w[l h u o L b a r H O].each { include_examples "interaction", _1 }
  %w[-n -A -F -G -S -L -s -u =m =p -D -- -f -r -o =R -g -c -d =S].each { include_examples "argument", _1 }
end
