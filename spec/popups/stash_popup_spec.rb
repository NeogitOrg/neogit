# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Stash Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("Z") }

  let(:view) do
    [
      " Stash                Snapshot       Use       Inspect   Transform              ",
      " z both               Z both         p pop     l List    b Branch               ",
      " i index              I index        a apply   v Show    B Branch here          ",
      " w worktree           W worktree     d drop              m Rename               ",
      " x keeping index      r to wip ref                       f Format patch         ",
      " P push                                                                         "
    ]
  end

  %w[z i w x P Z I W r p a d l b B m f].each { include_examples "interaction", _1 }
end
