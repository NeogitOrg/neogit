# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Commit Popup", :git, :nvim do
  describe "Actions" do
    describe "Create Commit" do
      before do
        File.write("example.txt", "hello, world")
        git.add("example.txt")
        nvim.refresh
      end

      it "can make a commit" do
        head = git.show("HEAD").split("\n").first

        nvim.keys("cc")
        nvim.keys("commit message")
        nvim.keys("<esc>q")

        expect(git.show("HEAD").split("\n").first).not_to eq head
      end
    end

    describe "Extend" do
      before do
        File.write("example.txt", "hello, world")
        git.add("example.txt")
        git.commit("first commit")
        nvim.refresh
      end

      it "Amends previous commit without editing message" do
        expect(git.log(1).entries.first.diff_parent.patch).to eq "example.txt --- Text\n1 hello, world\n"

        File.write("example.txt", "hello, world\ngoodbye, space")
        nvim.refresh
        nvim.move_to_line "example.txt"
        nvim.keys("sce")

        expect(git.log(1).entries.first.diff_parent.patch).to eq(
          "example.txt --- Text\n1 hello, world\n2 goodbye, space\n"
        )
      end
    end

    describe "Reword" do
      it "Opens editor to reword a commit" do
        nvim.keys("cw")
        nvim.keys("cc")
        nvim.keys("reworded!<esc>q")
        expect(git.log(1).entries.first.message).to eq("reworded!")
      end
    end

    describe "Amend" do
      before do
        File.write("example.txt", "hello, world")
        git.add("example.txt")
        git.commit("first commit")
        nvim.refresh
      end

      it "Amends previous commit and edits message" do
        expect(git.log(1).entries.first.diff_parent.patch).to eq "example.txt --- Text\n1 hello, world\n"

        File.write("example.txt", "hello, world\ngoodbye, space")
        nvim.refresh
        nvim.move_to_line "example.txt"
        nvim.keys("sca")
        nvim.keys("cc")
        nvim.keys("amended!<esc>q")

        expect(git.log(1).entries.first.message).to eq("amended!")
        expect(git.log(1).entries.first.diff_parent.patch).to eq(
          "example.txt --- Text\n1 hello, world\n2 goodbye, space\n"
        )
      end
    end

    describe "Fixup" do
    end

    describe "Squash" do
    end

    describe "Augment" do
    end

    describe "Instant Fixup" do
    end

    describe "Instant Squash" do
    end
  end
end
