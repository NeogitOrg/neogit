# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Ignore Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("i") }

  let(:view) do
    [
      " Gitignore                                                                      ",
      " t shared at top-level            (.gitignore)                                  ",
      " s shared in sub-directory        (path/to/.gitignore)                          ",
      " p privately for this repository  (.git/info/exclude)                           "
    ]
  end

  %w[t s p].each { include_examples "interaction", _1 }

  # context "when global ignore config is set" do
  #   before { git.config('') }
  #
  #   include_examples "interaction", "g"
  # end
end
