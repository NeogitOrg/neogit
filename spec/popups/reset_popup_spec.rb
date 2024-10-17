# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Reset Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("X") }

  let(:view) do
    [
      " Reset         Reset this                                                       ",
      " f file        m mixed    (HEAD and index)                                      ",
      " b branch      s soft     (HEAD only)                                           ",
      "               h hard     (HEAD, index and files)                               ",
      "               k keep     (HEAD and index, keeping uncommitted)                 ",
      "               i index    (only)                                                ",
      "               w worktree (only)                                                "
    ]
  end

  %w[f b m s h k i w].each { include_examples "interaction", _1 }
end
