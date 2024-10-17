# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Fetch Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("f") }

  let(:view) do
    [
      " Arguments                                                                      ",
      " -p Prune deleted branches (--prune)                                            ",
      " -t Fetch all tags (--tags)                                                     ",
      " -F force (--force)                                                             ",
      "                                                                                ",
      " Fetch from                      Fetch                Configure                 ",
      " p pushRemote, setting that      o another branch     C Set variables...        ",
      " u @{upstream}, setting it       r explicit refspec                             ",
      " e elsewhere                     m submodules                                   ",
      " a all remotes                                                                  "
    ]
  end

  %w[p u e a o r m C].each { include_examples "interaction", _1 }
  %w[-p -t -F].each { include_examples "argument", _1 }
end
