# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Bisect Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("B") }

  let(:view) do
    [
      " Arguments                                                                      ",
      " -r Don't checkout commits (--no-checkout)                                      ",
      " -p Follow only first parent of a merge (--first-parent)                        ",
      "                                                                                ",
      " Bisect                                                                         ",
      " B Start                                                                        ",
      " S Scripted                                                                     "
    ]
  end

  %w[-r -p].each { include_examples "argument", _1 }
  %w[B S].each { include_examples "interaction", _1 }
end
