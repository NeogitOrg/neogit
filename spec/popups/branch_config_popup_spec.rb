# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Branch Config Popup", :git, :nvim, :popup do
  before { nvim.keys("bC<cr>") }

  let(:view) do
    [
      " Configure branch                                                               ",
      " d branch.master.description unset                                              ",
      " u branch.master.merge unset                                                    ",
      "   branch.master.remote unset                                                   ",
      " r branch.master.rebase [true|false|pull.rebase:false]                          ",
      " p branch.master.pushRemote []                                                  ",
      "                                                                                ",
      " Configure repository defaults                                                  ",
      " R pull.rebase [true|false]                                                     ",
      " P remote.pushDefault []                                                        ",
      " b neogit.baseBranch unset                                                      ",
      " A neogit.askSetPushDefault [ask|ask-if-unset|never]                            ",
      "                                                                                ",
      " Configure branch creation                                                      ",
      " a s branch.autoSetupMerge [always|true|false|inherit|simple|default:true]      ",
      " a r branch.autoSetupRebase [always|local|remote|never|default:never]           "
    ]
  end

  %w[d u r p R P B A as ar].each { include_examples "interaction", _1 }

  describe "Variables" do
    describe "description" do
      it "sets description" do
        nvim.keys("d")
        nvim.keys("hello world<esc>q")
        expect(nvim.screen[5]).to start_with(" d branch.master.description hello world")
        expect(git.config("branch.master.description")).to eq("hello world\n")
      end
    end

    describe "merge" do
      it "sets merge and remote values" do
        nvim.keys("u<cr>")
        expect(nvim.errors).to be_empty
        expect(git.config("branch.master.merge")).to eq "refs/heads/master"
      end
    end

    # describe "rebase" do
    # end

    # describe "pullRemote" do
    # end
  end

  describe "Actions" do
    describe "pull.rebase" do
      it "changes pull.rebase" do
        nvim.keys("R")
        expect(git.config("pull.rebase")).to eq("true")
        nvim.keys("R")
        expect(git.config("pull.rebase")).to eq("false")
        nvim.keys("R")
        expect(git.config("pull.rebase")).to eq("true")

        expect(nvim.errors).to be_empty
      end
    end

    # describe "remote.pushDefault" do
    # end

    # describe "neogit.baseBranch" do
    # end

    # describe "neogit.askSetPushDefault" do
    # end
  end

  # describe "Branch creation" do
  #   describe "autoSetupMerge" do
  #   end
  #
  #   describe "autoSetupRebase" do
  #   end
  # end
end
