# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Rebase Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("r") }

  let(:view) do
    [
      " Arguments                                                                      ",
      " -k Keep empty commits (--keep-empty)                                           ",
      " -r Rebase merges (--rebase-merges=)                                            ",
      " -u Update branches (--update-refs)                                             ",
      " -d Use author date as committer date (--committer-date-is-author-date)         ",
      " -t Use current time as author date (--ignore-date)                             ",
      " -a Autosquash (--autosquash)                                                   ",
      " -A Autostash (--autostash)                                                     ",
      " -i Interactive (--interactive)                                                 ",
      " -h Disable hooks (--no-verify)                                                 ",
      " -S Sign using gpg (--gpg-sign=)                                                ",
      "                                                                                ",
      " Rebase master onto              Rebase                                         ",
      " p pushRemote, setting that      i interactively   m to modify a commit         ",
      " u @{upstream}, creating it      s a subset        w to reword a commit         ",
      " e elsewhere                                       d to remove a commit         ",
      "                                                   f to autosquash              "
    ]
  end

  %w[p u e i s m w d f].each { include_examples "interaction", _1 }
  %w[-k -r -u -d -t -a -A -i -h -S].each { include_examples "argument", _1 }
end
