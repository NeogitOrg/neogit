# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Push Popup", :git, :nvim, :popup, :with_remote_origin do
  before { nvim.keys("P") }

  let(:view) do
    [
      " Arguments                                                                      ",
      " -f Force with lease (--force-with-lease)                                       ",
      " -F Force (--force)                                                             ",
      " -h Disable hooks (--no-verify)                                                 ",
      " -d Dry run (--dry-run)                                                         ",
      " -u Set the upstream before pushing (--set-upstream)                            ",
      "                                                                                ",
      " Push master to                  Push                  Configure                ",
      " p pushRemote, setting that      o another branch      C Set variables...       ",
      " u @{upstream}, creating it      r explicit refspec                             ",
      " e elsewhere                     m matching branches                            ",
      "                                 T a tag                                        ",
      "                                 t all tags                                     "
    ]
  end

  %w[-f -F -u -h -d].each { include_examples "argument", _1 }
  %w[p u e o r m T t C].each { include_examples "interaction", _1 }

  describe "Actions" do
    describe "Push to branch.pushRemote" do
      context "when branch.pushRemote is unset" do
        it "sets branch.pushRemote" do
          nvim.keys("p")
          expect(git.config("branch.master.pushRemote")).to eq("origin")
        end

        it "pushes local commits to remote" do
          File.write("example.txt", "hello, world")
          git.add("example.txt")
          nvim.refresh

          nvim.keys("p")
          expect(git.show("HEAD").split[1]).to eq(git.remotes.first.branch.gcommit.sha)
        end
      end

      context "when remote has diverged" do
        it "prompts the user to force push (yes)" do
          File.write("example.txt", "hello, world")
          git.add("example.txt")
          git.commit("commit A")
          nvim.refresh

          nvim.keys("p")
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

          nvim.keys("p")
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
