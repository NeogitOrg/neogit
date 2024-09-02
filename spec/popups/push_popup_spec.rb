# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Push Popup", :git, :nvim, :with_remote_origin do
  describe "Actions" do
    describe "Push to branch.pushRemote" do
      context "when branch.pushRemote is unset" do
        it "sets branch.pushRemote" do
          nvim.keys("Pp")
          expect(git.config("branch.master.pushRemote")).to eq("origin")
        end

        it "pushes local commits to remote" do
          File.write("example.txt", "hello, world")
          git.add("example.txt")
          nvim.refresh

          nvim.keys("Pp")
          expect(git.show("HEAD").split[1]).to eq(git.remotes.first.branch.gcommit.sha)
        end
      end

      context "when remote has diverged" do
        it "prompts the user to force push (yes)" do
          File.write("example.txt", "hello, world")
          git.add("example.txt")
          git.commit("commit A")
          nvim.refresh

          nvim.keys("Pp")
          # nvim.keys("XhHEAD^<cr>") TODO
          `git reset --hard HEAD^`
          File.write("example.txt", "hello, world, again")
          git.add("example.txt")
          git.commit("commit B")

          nvim.confirm(true)
          nvim.keys("Pp")

          expect(git.show("HEAD").split[1]).to eq(git.remotes.first.branch.gcommit.sha)
        end

        it "prompts the user to force push (no)" do
          File.write("example.txt", "hello, world")
          git.add("example.txt")
          git.commit("commit A")
          nvim.refresh

          nvim.keys("Pp")
          # nvim.keys("XhHEAD^<cr>") TODO
          `git reset --hard HEAD^`
          File.write("example.txt", "hello, world, again")
          git.add("example.txt")
          git.commit("commit B")

          nvim.confirm(false)
          nvim.keys("Pp")

          expect(git.show("HEAD").split[1]).not_to eq(git.remotes.first.branch.gcommit.sha)
        end
      end
    end
  end
end
