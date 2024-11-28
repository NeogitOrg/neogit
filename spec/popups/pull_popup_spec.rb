# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Pull Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("p") }

  let(:view) do
    [
      " Variables                                                                      ",
      " r branch.master.rebase [true|false|pull.rebase:false]                          ",
      "                                                                                ",
      " Arguments                                                                      ",
      " -f Fast-forward only (--ff-only)                                               ",
      " -r Rebase local commits (--rebase)                                             ",
      " -a Autostash (--autostash)                                                     ",
      " -t Fetch tags (--tags)                                                         ",
      " -F Force (--force)                                                             ",
      "                                                                                ",
      " Pull into master from           Configure                                      ",
      " p pushRemote, setting that      C Set variables...                             ",
      " u @{upstream}, creating it                                                     ",
      " e elsewhere                                                                    "
    ]
  end

  %w[r -f -r -a -t -F p u e C].each { include_examples "interaction", _1 }
end
