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
