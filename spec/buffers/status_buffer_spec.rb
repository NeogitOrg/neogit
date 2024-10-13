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
end
