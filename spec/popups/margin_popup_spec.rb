# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Margin Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  let(:keymap) { "L" }
  let(:view) do
    [
      " Arguments                                                                      ",
      # " -n Limit number of commits (--max-count=256)                                   ",
      " -o Order commits by (--[topo|author-date|date]-order)                          ",
      # " -g Show graph (--graph)                                                        ",
      # " -c Show graph in color (--color)                                               ",
      " -d Show refnames (--decorate)                                                  ",
      "                                                                                ",
      " Refresh       Margin                                                           ",
      " g buffer      L toggle visibility                                              ",
      "               l cycle style                                                    ",
      "               d toggle details                                                 ",
      "               x toggle shortstat                                               "
    ]
  end

  %w[L l d g x].each { include_examples "interaction", _1 }
end
