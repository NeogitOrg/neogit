# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Tag Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  let(:keymap) { "t" }

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

  describe "Actions" do
    describe "Create tag" do
      it "creates a tag on the selected ref" do
        nvim.input("v1.0")
        nvim.keys("t")
        nvim.keys("HEAD<cr>")
        expect(git.tags.map(&:name)).to include("v1.0")
      end
    end

    describe "Delete tag" do
      before { git.add_tag("v1.0") }

      it "deletes the selected tag" do
        nvim.keys("x")
        nvim.keys("v1.0<cr>")
        expect(git.tags.map(&:name)).not_to include("v1.0")
      end
    end
  end
end
