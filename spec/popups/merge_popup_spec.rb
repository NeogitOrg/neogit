# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Merge Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("m") }

  let(:view) do
    [
      " Arguments                                                                      ",
      " -f Fast-forward only (--ff-only)                                               ",
      " -n No fast-forward (--no-ff)                                                   ",
      " -s Strategy (--strategy=)                                                      ",
      " -X Strategy Option (--strategy-option=)                                        ",
      " -b Ignore changes in amount of whitespace (-Xignore-space-change)              ",
      " -w Ignore whitespace when comparing lines (-Xignore-all-space)                 ",
      " -A Diff algorithm (-Xdiff-algorithm=)                                          ",
      " -S Sign using gpg (--gpg-sign=)                                                ",
      "                                                                                ",
      " Actions                                                                        ",
      " m Merge                       p Preview merge                                  ",
      " e Merge and edit message                                                       ",
      " n Merge but don't commit      s Squash merge                                   ",
      " a Absorb                      i Dissolve                                       "
    ]
  end

  %w[m e n s a p i].each { include_examples "interaction", _1 }
  %w[-f -n -s -X -b -w -A -S].each { include_examples "argument", _1 }
end
