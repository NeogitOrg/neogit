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
        expect(git.log(1).entries.first.diff_parent.patch).to eq <<~DIFF.strip
          diff --git a/example.txt b/example.txt
          deleted file mode 100644
          index 8c01d89..0000000
          --- a/example.txt
          +++ /dev/null
          @@ -1 +0,0 @@
          -hello, world
          \\ No newline at end of file
        DIFF

        File.write("example.txt", "hello, world\ngoodbye, space")
        git.add("example.txt")
        nvim.keys("ce")

        expect(git.log(1).entries.first.diff_parent.patch).to eq <<~DIFF.strip
          diff --git a/example.txt b/example.txt
          deleted file mode 100644
          index cfbe699..0000000
          --- a/example.txt
          +++ /dev/null
          @@ -1,2 +0,0 @@
          -hello, world
          -goodbye, space
          \\ No newline at end of file
        DIFF
      end
    end

    describe "Reword" do
      it "Opens editor to reword a commit" do
        nvim.keys("cw")
        nvim.keys("cc")
        nvim.keys("reworded!<esc>:w<cr>q")
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
        expect(git.log(1).entries.first.diff_parent.patch).to eq <<~DIFF.strip
          diff --git a/example.txt b/example.txt
          deleted file mode 100644
          index 8c01d89..0000000
          --- a/example.txt
          +++ /dev/null
          @@ -1 +0,0 @@
          -hello, world
          \\ No newline at end of file
        DIFF

        File.write("example.txt", "hello, world\ngoodbye, space")
        git.add("example.txt")
        nvim.keys("caccamended!<esc>:w<cr>q")

        expect(git.log(1).entries.first.message).to eq("amended!")
        expect(git.log(1).entries.first.diff_parent.patch).to eq <<~DIFF.strip
          diff --git a/example.txt b/example.txt
          deleted file mode 100644
          index cfbe699..0000000
          --- a/example.txt
          +++ /dev/null
          @@ -1,2 +0,0 @@
          -hello, world
          -goodbye, space
          \\ No newline at end of file
        DIFF
      end
    end
    #
    # describe "Fixup" do
    # end
    #
    # describe "Squash" do
    # end
    #
    # describe "Augment" do
    # end
    #
    # describe "Instant Fixup" do
    # end
    #
    # describe "Instant Squash" do
    # end
  end
end
