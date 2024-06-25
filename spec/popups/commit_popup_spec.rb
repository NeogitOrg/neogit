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
  end
end
