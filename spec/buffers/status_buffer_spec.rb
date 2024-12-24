# frozen_string_literal: true

require "spec_helper"

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

  describe "discarding section" do
    context "with 'untracked'" do
      before do
        create_file "file_1", "hello world, 1"
        create_file "file_2", "hello world, 2"
        create_file "file_3", "hello world, 3"
        nvim.refresh
      end

      it "can discard all untracked files" do
        expect(git.status.untracked).not_to be_empty

        nvim.move_to_line("Untracked files")
        nvim.confirm(true)
        nvim.keys("x")

        expect(git.status.untracked).to be_empty
      end
    end

    context "with 'unstaged'" do
      before do
        create_file "file_1", "hello world, 1"
        create_file "file_2", "hello world, 2"
        create_file "file_3", "hello world, 3"
        git.add("file_1")
        git.add("file_2")
        git.add("file_3")
        git.commit("added files")
        create_file "file_1", "world, 1"
        create_file "file_2", "world, 2"
        create_file "file_3", "world, 3"

        nvim.refresh
      end

      it "can discard all unstaged changes" do
        expect(git.status.changed).not_to be_empty

        nvim.move_to_line("Unstaged changes")
        nvim.confirm(true)
        nvim.keys("x")

        expect(git.status.changed).to be_empty
      end
    end

    context "with 'staged'" do
      before do
        create_file "file_1", "hello world, 1"
        create_file "file_2", "hello world, 2"
        create_file "file_3", "hello world, 3"
        git.add("file_1")
        git.add("file_2")
        git.add("file_3")

        nvim.refresh
      end

      it "can discard all staged changes" do
        expect(git.status.added).not_to be_empty

        nvim.move_to_line("Staged changes")
        nvim.confirm(true)
        nvim.keys("x")

        expect(git.status.added).to be_empty
      end
    end
  end

  describe "discarding file" do
    context "with 'untracked'" do
      before do
        create_file "file_1", "hello world, 1"
        create_file "file_2", "hello world, 2"
        nvim.refresh
      end

      it "can discard individual untracked files" do
        nvim.move_to_line("file_1")
        nvim.confirm(true)
        nvim.keys("x")

        expect(git.status.untracked.keys).to contain_exactly("file_2")

        nvim.keys("x")
        expect(git.status.untracked).to be_empty
      end
    end

    context "with 'unstaged'" do
      before do
        create_file "file_1", "hello world, 1"
        create_file "file_2", "hello world, 2"
        git.add("file_1")
        git.add("file_2")
        git.commit("added files")
        create_file "file_1", "world, 1"
        create_file "file_2", "world, 2"

        nvim.refresh
      end

      it "can discard individual unstaged changes" do
        nvim.move_to_line("file_1")
        nvim.confirm(true)
        nvim.keys("x")

        expect(git.status.changed.keys).to contain_exactly("file_2")

        nvim.keys("x")
        expect(git.status.changed).to be_empty
      end
    end

    context "with 'staged'" do
      before do
        create_file "file_1", "hello world, 1"
        create_file "file_2", "hello world, 2"
        git.add("file_1")
        git.add("file_2")

        nvim.refresh
      end

      it "can discard all staged changes" do
        nvim.move_to_line("file_1")
        nvim.confirm(true)
        nvim.keys("x")

        expect(git.status.added.keys).to contain_exactly("file_2")

        nvim.keys("x")
        expect(git.status.changed).to be_empty
      end
    end
  end

  describe "discarding hunk" do
  end
end
