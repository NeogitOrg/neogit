# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Ignore Popup", :git, :nvim, :popup do
  let(:keymap) { "i" }
  let(:view) do
    [
      " Gitignore                                                                      ",
      " t shared at top-level            (.gitignore)                                  ",
      " s shared in sub-directory        (path/to/.gitignore)                          ",
      " p privately for this repository  (.git/info/exclude)                           "
    ]
  end

  %w[t s p].each { include_examples "interaction", _1 }

  describe "Actions" do
    describe "Shared at top-level" do
      before do
        File.write("secret.key", "topsecret")
        nvim.refresh
      end

      it "adds the untracked file to .gitignore" do
        nvim.keys("t")
        nvim.keys("secr<cr>")
        expect(File.exist?(".gitignore")).to be true
        expect(File.read(".gitignore")).to include("secret.key")
      end
    end

    describe "Privately for this repository" do
      before do
        File.write("local_secret.txt", "local")
        nvim.refresh
      end

      it "adds the file to .git/info/exclude" do
        nvim.keys("p")
        nvim.keys("local<cr>")
        exclude = File.join(".git", "info", "exclude")
        expect(File.exist?(exclude)).to be true
        expect(File.read(exclude)).to include("local_secret.txt")
      end
    end
  end

  # context "when global ignore config is set" do
  #   before { git.config('') }
  #
  #   include_examples "interaction", "g"
  # end
end
