# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Branch Config Popup", :git, :nvim do
  before do
    nvim.keys("bC<cr>")
  end

  describe "Variables" do
    describe "description" do
      it "sets description" do
        nvim.keys("d")
        nvim.keys("hello world<cr>")
        expect(nvim.screen[5]).to eq(" d branch.master.description hello world                                        ")
        expect(git.config("branch.master.description")).to eq("hello world")
      end
    end

    describe "merge" do
      it "sets merge and remote values" do
        nvim.keys("u<cr>")
        expect(nvim.errors).to be_empty
        expect(git.config("branch.master.merge")).to eq "refs/heads/master"
      end
    end

    describe "rebase" do
    end

    describe "pullRemote" do
    end
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

    describe "remote.pushDefault" do
    end

    describe "neogit.baseBranch" do
    end

    describe "neogit.askSetPushDefault" do
    end
  end

  describe "Branch creation" do
    describe "autoSetupMerge" do
      
    end

    describe "autoSetupRebase" do
      
    end
  end
end
