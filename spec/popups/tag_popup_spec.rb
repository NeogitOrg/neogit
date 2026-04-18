# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Tag Popup", :git, :nvim, :popup do
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

    describe "Create release tag" do
      context "without an existing tag" do
        it "creates a tag on HEAD" do
          nvim.input("v1.0.0")
          nvim.keys("r")
          expect(git.tags.map(&:name)).to include("v1.0.0")
        end
      end

      context "with an existing tag" do
        before { git.add_tag("v1.0.0") }

        it "uses the highest tag as the default name" do
          # User clears the default and types the new version
          nvim.keys("r")
          nvim.keys("<c-u>v2.0.0<cr>")
          expect(git.tags.map(&:name)).to include("v2.0.0")
        end
      end

      context "with --annotate enabled" do
        before do
          nvim.keys("-a")
          git.add_tag("v1.0.0", annotate: true, message: "My Project 1.0.0")
        end

        it "creates an annotated tag with a proposed message derived from the previous tag" do
          nvim.keys("r")
          # Clear the default tag name and enter the new version
          nvim.keys("<c-u>v2.0.0<cr>")
          # Accept the proposed message ("My Project 2.0.0" derived from old "My Project 1.0.0")
          nvim.keys("<cr>")
          expect(git.tags.map(&:name)).to include("v2.0.0")
          expect(git.tags.find { |t| t.name == "v2.0.0" }.message).to eq("My Project 2.0.0")
        end
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
