# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Tag Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("t") }

  let(:view) do
    [
      " Arguments                                                                      ",
      " -f Force (--force)                                                             ",
      " -a Annotate (--annotate)                                                       ",
      " -s Sign (--sign)                                                               ",
      " -u Sign as (--local-user=)                                                     ",
      "                                                                                ",
      " Create         Do                                                              ",
      " t tag          x delete                                                        ",
      " r release      p prune                                                         "
    ]
  end

  %w[t r x p].each { include_examples "interaction", _1 }
  %w[-f -a -s -u].each { include_examples "argument", _1 }
end
