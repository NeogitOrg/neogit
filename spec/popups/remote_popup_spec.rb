# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Remote Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("M") }

  let(:view) do
    [
      " Variables                                                                      ",
      " u remote.origin.url unset                                                      ",
      " U remote.origin.fetch unset                                                    ",
      " s remote.origin.pushurl unset                                                  ",
      " S remote.origin.push unset                                                     ",
      " O remote.origin.tagOpt [--no-tags|--tags]                                      ",
      "                                                                                ",
      " Arguments                                                                      ",
      " -f Fetch after add (-f)                                                        ",
      "                                                                                ",
      " Actions                                                                        ",
      " a Add         C Configure...                                                   ",
      " r Rename      p Prune stale branches                                           ",
      " x Remove      P Prune stale refspecs                                           ",
      "               b Update default branch                                          ",
      "               z Unshallow remote                                               "
    ]
  end

  %w[u U s S O a d x C p P b z].each { include_examples "interaction", _1 }
  %w[-f].each { include_examples "argument", _1 }
end
