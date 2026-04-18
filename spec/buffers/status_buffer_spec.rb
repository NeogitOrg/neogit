# frozen_string_literal: true

require "spec_helper"
require "fileutils"

RSpec.describe "Status Buffer", :git, :nvim do
  it "renders, raising no errors" do
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitStatus")
  end

  context "with a file that only has a number as the filename" do
    before do
      create_file("1")
      nvim.refresh
    end

    it "renders, raising no errors" do
      expect(nvim.errors).to be_empty
      expect(nvim.filetype).to eq("NeogitStatus")
    end
  end

  context "when a file's mode changes" do
    before do
      create_file("test")
      git.add("test")
      git.commit("commit")
      system("chmod +x test")
      nvim.refresh
    end

    it "renders, raising no errors" do
      expect(nvim.errors).to be_empty
      expect(nvim.filetype).to eq("NeogitStatus")
      expect(nvim.screen[6]).to eq("> modified   test 100644 -> 100755                                              ")
    end
  end

  context "with disabled mapping and no replacement" do
    let(:neogit_config) { "{ mappings = { status = { j = false }, popup = { b = false } } }" }

    it "renders, raising no errors" do
      expect(nvim.errors).to be_empty
      expect(nvim.filetype).to eq("NeogitStatus")
    end
  end

  describe "staging" do
    context "with untracked file" do
      before do
        create_file("example.txt", "1 foo\n2 foo\n3 foo\n4 foo\n5 foo\n6 foo\n7 foo\n8 foo\n9 foo\n10 foo\n")
        nvim.refresh
        nvim.move_to_line("example.txt", after: "Untracked files")
      end

      it "can stage a file" do
        nvim.keys("s")
        expect(nvim.screen[5..6]).to eq(
          [
            "v Staged changes (1)                                                            ",
            "> new file   example.txt                                                        "
          ]
        )
      end

      it "can stage one line" do
        nvim.keys("<tab>jjjVs")
        nvim.move_to_line("new file")
        nvim.keys("<tab>")
        expect(nvim.screen[8..12]).to eq(
          [
            "v Staged changes (1)                                                            ",
            "v new file   example.txt                                                        ",
            "  @@ -0,0 +1 @@                                                                 ",
            "  +2 foo                                                                        ",
            "                                                                                "
          ]
        )
      end
    end

    # context "with tracked file" do
    # end
  end

  describe "staging tracked files" do
    before do
      File.write("foo", "original content\n")
      git.add("foo")
      git.commit("initial commit")
      File.write("foo", "modified content\n")
      nvim.refresh
    end

    it "stages an unstaged tracked file" do
      nvim.move_to_line("modified   foo", after: "Unstaged changes")
      nvim.keys("s")
      await { expect(`git diff --cached --name-only`.strip).to eq("foo") }
    end
  end

  describe "stage all / stage unstaged" do
    before do
      File.write("tracked", "original\n")
      git.add("tracked")
      git.commit("initial commit")
      File.write("tracked", "modified\n") # unstaged
      File.write("untracked", "new file\n") # untracked
      nvim.refresh
    end

    it "stages all files with <c-s>" do
      nvim.keys("<c-s>")
      await do
        expect(`git diff --cached --name-only`.strip).to include("tracked")
        expect(`git diff --cached --name-only`.strip).to include("untracked")
      end
    end

    it "stages only unstaged tracked files with S" do
      nvim.keys("S")
      await do
        expect(`git diff --cached --name-only`.strip).to eq("tracked")
        expect(git.status.untracked).not_to be_empty
      end
    end
  end

  describe "unstaging" do
    before do
      File.write("foo", "original\n")
      git.add("foo")
      git.commit("initial commit")
      File.write("foo", "modified\n")
      git.add("foo")
      nvim.refresh
    end

    it "unstages a staged file with u" do
      nvim.move_to_line("modified   foo", after: "Staged changes")
      nvim.keys("u")
      await do
        expect(`git diff --cached --name-only`.strip).to be_empty
        expect(git.status.changed.keys).to contain_exactly("foo")
      end
    end

    it "unstages everything with U" do
      nvim.keys("U")
      await do
        expect(`git diff --cached --name-only`.strip).to be_empty
        expect(git.status.changed.keys).to contain_exactly("foo")
      end
    end

    it "unstages a visual selection with u" do
      nvim.move_to_line("modified   foo", after: "Staged changes")
      nvim.keys("Vu") # visual line mode, then unstage
      await do
        expect(`git diff --cached --name-only`.strip).to be_empty
        expect(git.status.changed.keys).to contain_exactly("foo")
      end
    end
  end

  describe "discarding" do
    context "unstaged tracked file" do
      before do
        File.write("foo", "original\n")
        git.add("foo")
        git.commit("initial commit")
        File.write("foo", "modified\n")
        nvim.refresh
      end

      it "reverts file content to HEAD" do
        nvim.move_to_line("modified   foo", after: "Unstaged changes")
        nvim.confirm(true)
        nvim.keys("x")
        await do
          expect(File.read("foo")).to eq("original\n")
          expect(git.status.changed).to be_empty
        end
      end
    end

    context "untracked file" do
      before do
        File.write("new_file.txt", "brand new\n")
        nvim.refresh
      end

      it "deletes the file" do
        nvim.move_to_line("new_file.txt", after: "Untracked files")
        nvim.confirm(true)
        nvim.keys("x")
        await { expect(File.exist?("new_file.txt")).to be false }
      end
    end

    context "staged new file" do
      before do
        File.write("new_file.txt", "brand new\n")
        git.add("new_file.txt")
        nvim.refresh
      end

      it "removes it from the index and deletes the file" do
        nvim.move_to_line("new file   new_file.txt", after: "Staged changes")
        nvim.confirm(true)
        nvim.keys("x")
        await do
          expect(`git diff --cached --name-only`.strip).to be_empty
          expect(File.exist?("new_file.txt")).to be false
        end
      end
    end

    context "staged modification" do
      before do
        File.write("foo", "original\n")
        git.add("foo")
        git.commit("initial commit")
        File.write("foo", "modified\n")
        git.add("foo")
        nvim.refresh
      end

      it "reverts file content and unstages it" do
        nvim.move_to_line("modified   foo", after: "Staged changes")
        nvim.confirm(true)
        nvim.keys("x")
        await do
          expect(File.read("foo")).to eq("original\n")
          expect(`git diff --cached --name-only`.strip).to be_empty
        end
      end

      it "discards a staged hunk" do
        nvim.move_to_line("modified   foo", after: "Staged changes")
        nvim.keys("<tab>")
        nvim.move_to_line("+modified")
        nvim.confirm(true)
        nvim.keys("x")
        await do
          expect(File.read("foo")).to eq("original\n")
          expect(`git diff --cached --name-only`.strip).to be_empty
        end
      end

      it "discards a visual selection with x" do
        nvim.move_to_line("modified   foo", after: "Staged changes")
        nvim.confirm(true)
        nvim.keys("Vx") # visual line select file header, discard
        await do
          expect(File.read("foo")).to eq("original\n")
          expect(`git diff --cached --name-only`.strip).to be_empty
        end
      end
    end
  end

  describe "visual reverse" do
    before do
      File.write("foo", "line one\nline two\nline three\n")
      git.add("foo")
      git.commit("initial commit")
      File.write("foo", "line one\nLINE TWO\nline three\n")
      git.add("foo")
      nvim.refresh
    end

    it "reverses a visual selection of staged lines back into the worktree" do
      nvim.move_to_line("modified   foo", after: "Staged changes")
      nvim.keys("<tab>") # expand hunk
      nvim.move_to_line("+LINE TWO")
      nvim.confirm(true)
      nvim.keys("V-") # visual line select the addition, then reverse
      await do
        # Only the addition (+LINE TWO) is reversed — it's removed from the worktree.
        # The deletion (-line two) was not selected, so "line two" is not restored.
        expect(File.read("foo")).to eq("line one\nline three\n")
        expect(`git diff --cached --name-only`.strip).to eq("foo")
      end
    end
  end

  describe "untracking" do
    before do
      File.write("foo", "tracked content\n")
      git.add("foo")
      git.commit("initial commit")
      nvim.refresh
    end

    it "removes a file from git tracking while keeping it on disk" do
      nvim.keys("K")
      nvim.keys("foo<cr>")
      await do
        expect(File.exist?("foo")).to be true
        expect(`git ls-files foo`.strip).to be_empty
      end
    end
  end

  describe "reversing" do
    before do
      File.write("foo", "original content\n")
      git.add("foo")
      git.commit("initial commit")
      File.write("foo", "modified content\n")
      git.add("foo")
      nvim.refresh
    end

    it "reverses a staged file back into the working tree" do
      nvim.move_to_line("modified   foo", after: "Staged changes")
      nvim.confirm(true)
      nvim.keys("-")
      await do
        expect(File.read("foo")).to eq("original content\n")
        expect(`git diff --cached --name-only`.strip).to eq("foo")
      end
    end

    it "reverses all staged files when cursor is on the section header" do
      nvim.move_to_line("Staged changes")
      nvim.confirm(true)
      nvim.keys("-")
      await do
        expect(File.read("foo")).to eq("original content\n")
        expect(`git diff --cached --name-only`.strip).to eq("foo")
      end
    end

    it "reverses a staged hunk back into the working tree" do
      nvim.move_to_line("modified   foo", after: "Staged changes")
      nvim.keys("<tab>") # expand hunk
      nvim.move_to_line("+modified content")
      nvim.confirm(true)
      nvim.keys("-")
      await do
        expect(File.read("foo")).to eq("original content\n")
        expect(`git diff --cached --name-only`.strip).to eq("foo")
      end
    end

    it "warns and does nothing when trying to reverse unstaged changes" do
      File.write("bar", "original bar\n")
      git.add("bar")
      git.commit("add bar")
      File.write("bar", "modified bar\n")
      nvim.refresh
      nvim.move_to_line("modified   bar", after: "Unstaged changes")
      nvim.keys("-")
      expect(nvim.errors).to be_empty
      expect(File.read("bar")).to eq("modified bar\n")
    end
  end

  describe "submodule navigation" do
    let(:submodule_path) { File.join("deps", "nested-submodule") }
    let(:submodule_repo_root) { File.expand_path(submodule_path) }
    let!(:submodule_source_dir) { Dir.mktmpdir("neogit-submodule-source") }

    before do
      initialize_submodule_source

      git.config("protocol.file.allow", "always")
      unless system("git", "-c", "protocol.file.allow=always", "submodule", "add", submodule_source_dir, submodule_path)
        raise "Failed to add submodule"
      end

      git.commit("Add submodule")

      File.open(File.join(submodule_path, "file.txt"), "a") { _1.puts("local change") }
      nvim.lua(<<~LUA)
        local status = require("neogit.buffers.status")
        local instance = status.instance()
        if instance then
          status.register(instance, vim.uv.cwd())
        end
      LUA
      nvim.refresh
    end

    after do
      FileUtils.remove_entry(submodule_source_dir) if File.directory?(submodule_source_dir)
    end

    it "opens submodule status and returns to the parent repo twice" do
      # First jump and back
      await do
        expect(nvim.screen.join("\n")).to include("#{submodule_path} (modified content)")
      end

      nvim.move_to_line(submodule_path)
      nvim.keys("<cr>")

      await do
        expect(nvim.fn("getcwd", [])).to eq(submodule_repo_root)
        expect(nvim.screen.join("\n")).to include("modified   file.txt")
      end

      nvim.keys("gp")

      await do
        expect(nvim.fn("getcwd", [])).to eq(Dir.pwd)
        expect(nvim.screen.join("\n")).to include("#{submodule_path} (modified content)")
      end

      # Second jump and back
      nvim.move_to_line(submodule_path)
      nvim.keys("<cr>")

      await do
        expect(nvim.fn("getcwd", [])).to eq(submodule_repo_root)
        expect(nvim.screen.join("\n")).to include("modified   file.txt")
      end

      nvim.keys("gp")

      await do
        expect(nvim.fn("getcwd", [])).to eq(Dir.pwd)
        expect(nvim.screen.join("\n")).to include("#{submodule_path} (modified content)")
      end
    end

    def initialize_submodule_source
      repo = Git.init(submodule_source_dir)
      repo.config("user.email", "test@example.com")
      repo.config("user.name", "tester")
      File.write(File.join(submodule_source_dir, "file.txt"), "submodule file\n")
      repo.add("file.txt")
      repo.commit("Initial submodule commit")
    end
  end
end
