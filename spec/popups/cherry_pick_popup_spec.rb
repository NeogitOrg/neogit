# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Cherry Pick Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  let(:keymap) { "A" }
  let(:view) do
    [
      "Arguments                                                                       ",
      "-m Replay merge relative to parent (--mainline=)                                ",
      "=s Strategy (--strategy=)                                                       ",
      "-F Attempt fast-forward (--ff)                                                  ",
      "-x Reference cherry in commit message (-x)                                      ",
      "-e Edit commit messages (--edit)                                                ",
      "-s Add Signed-off-by lines (--signoff)                                          ",
      "-S Sign using gpg (--gpg-sign=)                                                 ",
      "                                                                                ",
      "Apply here      Apply elsewhere                                                 ",
      "A Pick          d Donate                                                        ",
      "a Apply         n Spinout                                                       ",
      "h Harvest       s Spinoff                                                       ",
      "m Squash                                                                        "
    ]
  end

  %w[-m =s -F -x -e -s -S].each { it_behaves_like "argument", it }
  %w[A a m d h n s].each { it_behaves_like "interaction", it }
end
